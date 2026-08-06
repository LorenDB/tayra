from django.db.models import Count, OuterRef, Prefetch, Q, Subquery, Sum
from django.db.models.functions import Coalesce, Length
from drf_spectacular.utils import extend_schema
from rest_framework import decorators as rest_decorators
from rest_framework import mixins, response, viewsets

from funkwhale_api.audio import models as audio_models
from funkwhale_api.common import models as common_models
from funkwhale_api.common import preferences
from funkwhale_api.common.mixins import MultipleLookupDetailMixin
from funkwhale_api.favorites import models as favorites_models
from funkwhale_api.history import models as history_models
from funkwhale_api.music import models as music_models
from funkwhale_api.music import views as music_views
from funkwhale_api.playlists import models as playlists_models
from funkwhale_api.tags import models as tags_models
from funkwhale_api.users import models as users_models

from . import filters, serializers


def get_stats(tracks, target, ignore_fields=[]):
    tracks = list(tracks.values_list("pk", flat=True))
    uploads = music_models.Upload.objects.filter(track__in=tracks)
    fields = {
        "listenings": history_models.Listening.objects.filter(track__in=tracks),
        "mutations": common_models.Mutation.objects.get_for_target(target),
        "playlists": (
            playlists_models.PlaylistTrack.objects.filter(track__in=tracks)
            .values_list("playlist", flat=True)
            .distinct()
        ),
        "track_favorites": (
            favorites_models.TrackFavorite.objects.filter(track__in=tracks)
        ),
        "libraries": (
            uploads.filter(library__channel=None)
            .values_list("library", flat=True)
            .distinct()
        ),
        "channels": (
            uploads.exclude(library__channel=None)
            .values_list("library", flat=True)
            .distinct()
        ),
        "uploads": uploads,
    }
    data = {}
    for key, qs in fields.items():
        if key in ignore_fields:
            continue
        data[key] = qs.count()

    data.update(get_media_stats(uploads))
    return data


def get_media_stats(uploads):
    data = {}
    data["media_total_size"] = uploads.aggregate(v=Sum("size"))["v"] or 0
    data["media_downloaded_size"] = (
        uploads.with_file().aggregate(v=Sum("size"))["v"] or 0
    )
    return data


class ManageArtistViewSet(
    mixins.ListModelMixin,
    mixins.RetrieveModelMixin,
    mixins.DestroyModelMixin,
    viewsets.GenericViewSet,
):
    queryset = (
        music_models.Artist.objects.all()
        .order_by("-id")
        .select_related("attachment_cover", "channel")
        .annotate(
            _tracks_count=Count("artist_credit__tracks", distinct=True),
            _albums_count=Count("artist_credit__albums", distinct=True),
        )
        .prefetch_related(music_views.TAG_PREFETCH)
    )
    serializer_class = serializers.ManageArtistSerializer
    filterset_class = filters.ManageArtistFilterSet
    required_scope = "instance:libraries"
    ordering_fields = ["creation_date", "name"]

    @extend_schema(operation_id="admin_get_library_artist_stats")
    @rest_decorators.action(methods=["get"], detail=True)
    def stats(self, request, *args, **kwargs):
        artist = self.get_object()
        tracks = music_models.Track.objects.filter(
            Q(artist_credit__artist=artist) | Q(album__artist_credit__artist=artist)
        )
        data = get_stats(tracks, artist)
        return response.Response(data, status=200)

    @rest_decorators.action(methods=["post"], detail=False)
    def action(self, request, *args, **kwargs):
        queryset = self.get_queryset()
        serializer = serializers.ManageArtistActionSerializer(
            request.data, queryset=queryset
        )
        serializer.is_valid(raise_exception=True)
        result = serializer.save()
        return response.Response(result, status=200)

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context["description"] = self.action in ["retrieve", "create", "update"]
        return context


class ManageAlbumViewSet(
    mixins.ListModelMixin,
    mixins.RetrieveModelMixin,
    mixins.DestroyModelMixin,
    viewsets.GenericViewSet,
):
    queryset = (
        music_models.Album.objects.all()
        .order_by("-id")
        .select_related("attachment_cover")
        .prefetch_related("artist_credit__artist")
        .prefetch_related("tracks")
    )
    serializer_class = serializers.ManageAlbumSerializer
    filterset_class = filters.ManageAlbumFilterSet
    required_scope = "instance:libraries"
    ordering_fields = ["creation_date", "title", "release_date"]

    @extend_schema(operation_id="admin_get_library_album_stats")
    @rest_decorators.action(methods=["get"], detail=True)
    def stats(self, request, *args, **kwargs):
        album = self.get_object()
        data = get_stats(album.tracks.all(), album)
        return response.Response(data, status=200)

    @rest_decorators.action(methods=["post"], detail=False)
    def action(self, request, *args, **kwargs):
        queryset = self.get_queryset()
        serializer = serializers.ManageAlbumActionSerializer(
            request.data, queryset=queryset
        )
        serializer.is_valid(raise_exception=True)
        result = serializer.save()
        return response.Response(result, status=200)

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context["description"] = self.action in ["retrieve", "create", "update"]
        return context


uploads_subquery = (
    music_models.Upload.objects.filter(track_id=OuterRef("pk"))
    .order_by()
    .values("track_id")
    .annotate(track_count=Count("track_id"))
    .values("track_count")
)


class ManageTrackViewSet(
    mixins.ListModelMixin,
    mixins.RetrieveModelMixin,
    mixins.DestroyModelMixin,
    viewsets.GenericViewSet,
):
    queryset = (
        music_models.Track.objects.all()
        .order_by("-id")
        .select_related("album__attachment_cover", "attachment_cover")
        .prefetch_related("artist_credit__artist", "album__artist_credit__artist")
        .annotate(uploads_count=Coalesce(Subquery(uploads_subquery), 0))
        .prefetch_related(music_views.TAG_PREFETCH)
    )
    serializer_class = serializers.ManageTrackSerializer
    filterset_class = filters.ManageTrackFilterSet
    required_scope = "instance:libraries"
    ordering_fields = [
        "creation_date",
        "title",
        "album__release_date",
        "position",
        "disc_number",
    ]

    @extend_schema(operation_id="admin_get_track_stats")
    @rest_decorators.action(methods=["get"], detail=True)
    def stats(self, request, *args, **kwargs):
        track = self.get_object()
        data = get_stats(track.__class__.objects.filter(pk=track.pk), track)
        return response.Response(data, status=200)

    @rest_decorators.action(methods=["post"], detail=False)
    def action(self, request, *args, **kwargs):
        queryset = self.get_queryset()
        serializer = serializers.ManageTrackActionSerializer(
            request.data, queryset=queryset
        )
        serializer.is_valid(raise_exception=True)
        result = serializer.save()
        return response.Response(result, status=200)

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context["description"] = self.action in ["retrieve", "create", "update"]
        return context


uploads_subquery = (
    music_models.Upload.objects.filter(library_id=OuterRef("pk"))
    .order_by()
    .values("library_id")
    .annotate(library_count=Count("library_id"))
    .values("library_count")
)


class ManageLibraryViewSet(
    mixins.ListModelMixin,
    mixins.RetrieveModelMixin,
    mixins.UpdateModelMixin,
    mixins.DestroyModelMixin,
    viewsets.GenericViewSet,
):
    lookup_field = "uuid"
    queryset = (
        music_models.Library.objects.all()
        .filter(channel=None)
        .order_by("-id")
        .select_related("owner")
        .annotate(
            _uploads_count=Coalesce(Subquery(uploads_subquery), 0),
        )
    )
    serializer_class = serializers.ManageLibrarySerializer
    filterset_class = filters.ManageLibraryFilterSet
    required_scope = "instance:libraries"

    @extend_schema(operation_id="admin_get_library_stats")
    @rest_decorators.action(methods=["get"], detail=True)
    def stats(self, request, *args, **kwargs):
        library = self.get_object()
        uploads = library.uploads.all()
        tracks = uploads.values_list("track", flat=True).distinct()
        albums = (
            music_models.Track.objects.filter(pk__in=tracks)
            .values_list("album", flat=True)
            .distinct()
        )
        artists = set(
            music_models.ArtistCredit.objects.filter(albums__pk__in=albums).values_list(
                "artist", flat=True
            )
        ) | set(
            music_models.ArtistCredit.objects.filter(tracks__pk__in=tracks).values_list(
                "artist", flat=True
            )
        )

        data = {
            "uploads": uploads.count(),
            "tracks": tracks.count(),
            "albums": albums.count(),
            "artists": len(artists),
        }
        data.update(get_media_stats(uploads.all()))
        return response.Response(data, status=200)

    @rest_decorators.action(methods=["post"], detail=False)
    def action(self, request, *args, **kwargs):
        queryset = self.get_queryset()
        serializer = serializers.ManageTrackActionSerializer(
            request.data, queryset=queryset
        )
        serializer.is_valid(raise_exception=True)
        result = serializer.save()
        return response.Response(result, status=200)


class ManageUploadViewSet(
    mixins.ListModelMixin,
    mixins.RetrieveModelMixin,
    mixins.DestroyModelMixin,
    viewsets.GenericViewSet,
):
    lookup_field = "uuid"
    queryset = (
        music_models.Upload.objects.all()
        .order_by("-id")
        .select_related("library__owner")
        .prefetch_related(
            "track__artist_credit__artist", "track__album__artist_credit__artist"
        )
    )
    serializer_class = serializers.ManageUploadSerializer
    filterset_class = filters.ManageUploadFilterSet
    required_scope = "instance:libraries"

    @rest_decorators.action(methods=["post"], detail=False)
    def action(self, request, *args, **kwargs):
        queryset = self.get_queryset()
        serializer = serializers.ManageUploadActionSerializer(
            request.data, queryset=queryset
        )
        serializer.is_valid(raise_exception=True)
        result = serializer.save()
        return response.Response(result, status=200)


class ManageUserViewSet(
    mixins.ListModelMixin,
    mixins.RetrieveModelMixin,
    mixins.UpdateModelMixin,
    mixins.DestroyModelMixin,
    viewsets.GenericViewSet,
):
    queryset = users_models.User.objects.all().order_by("-id")
    serializer_class = serializers.ManageUserSerializer
    filterset_class = filters.ManageUserFilterSet
    required_scope = "instance:users"
    ordering_fields = ["date_joined", "last_activity", "username"]

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context["default_permissions"] = preferences.get("users__default_permissions")
        return context

    def destroy(self, request, *args, **kwargs):
        """Permanently delete a local user account (async cascade).

        Admins cannot delete their own account through this endpoint — use the
        self-service deactivate/delete flows instead.
        """
        from funkwhale_api.users import tasks as users_tasks

        instance = self.get_object()
        if instance.pk == request.user.pk:
            return response.Response(
                {"detail": "You cannot delete your own account from user management."},
                status=400,
            )
        # Lock the account out immediately; hard-delete runs in the background.
        instance.deactivate()
        users_tasks.delete_account.delay(user_id=instance.pk)
        return response.Response(status=204)


class ManageInvitationViewSet(
    mixins.CreateModelMixin,
    mixins.ListModelMixin,
    mixins.RetrieveModelMixin,
    mixins.UpdateModelMixin,
    viewsets.GenericViewSet,
):
    queryset = (
        users_models.Invitation.objects.all()
        .order_by("-id")
        .prefetch_related("users")
        .select_related("owner")
    )
    serializer_class = serializers.ManageInvitationSerializer
    filterset_class = filters.ManageInvitationFilterSet
    required_scope = "instance:invitations"
    ordering_fields = ["creation_date", "expiration_date"]

    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)

    @rest_decorators.action(methods=["post"], detail=False)
    def action(self, request, *args, **kwargs):
        queryset = self.get_queryset()
        serializer = serializers.ManageInvitationActionSerializer(
            request.data, queryset=queryset
        )
        serializer.is_valid(raise_exception=True)
        result = serializer.save()
        return response.Response(result, status=200)


class ManageTagViewSet(
    mixins.ListModelMixin,
    mixins.RetrieveModelMixin,
    mixins.DestroyModelMixin,
    mixins.CreateModelMixin,
    viewsets.GenericViewSet,
):
    lookup_field = "name"
    queryset = (
        tags_models.Tag.objects.all()
        .order_by("-creation_date")
        .annotate(items_count=Count("tagged_items"))
        .annotate(length=Length("name"))
    )
    serializer_class = serializers.ManageTagSerializer
    filterset_class = filters.ManageTagFilterSet
    required_scope = "instance:libraries"
    ordering_fields = ["id", "creation_date", "name", "items_count", "length"]

    def get_queryset(self):
        queryset = super().get_queryset()
        from django.contrib.contenttypes.models import ContentType

        album_ct = ContentType.objects.get_for_model(music_models.Album)
        track_ct = ContentType.objects.get_for_model(music_models.Track)
        artist_ct = ContentType.objects.get_for_model(music_models.Artist)
        queryset = queryset.annotate(
            _albums_count=Count(
                "tagged_items", filter=Q(tagged_items__content_type=album_ct)
            ),
            _tracks_count=Count(
                "tagged_items", filter=Q(tagged_items__content_type=track_ct)
            ),
            _artists_count=Count(
                "tagged_items", filter=Q(tagged_items__content_type=artist_ct)
            ),
        )
        return queryset

    @rest_decorators.action(methods=["post"], detail=False)
    def action(self, request, *args, **kwargs):
        queryset = self.get_queryset()
        serializer = serializers.ManageTagActionSerializer(
            request.data, queryset=queryset
        )
        serializer.is_valid(raise_exception=True)
        result = serializer.save()
        return response.Response(result, status=200)

    @rest_decorators.action(methods=["post"], detail=False)
    def purge(self, request, *args, **kwargs):
        qs = self.get_queryset().filter(items_count=0)
        count = qs.count()
        qs.delete()
        return response.Response({"count": count, "action": "purge"}, status=200)


class ManageChannelViewSet(
    MultipleLookupDetailMixin,
    mixins.ListModelMixin,
    mixins.RetrieveModelMixin,
    mixins.DestroyModelMixin,
    viewsets.GenericViewSet,
):
    url_lookups = [
        {
            "lookup_field": "uuid",
            "validator": serializers.serializers.UUIDField().to_internal_value,
        },
        {
            "lookup_field": "username",
            "validator": lambda v: v,
            "get_query": lambda v: Q(preferred_username__iexact=v),
        },
    ]
    queryset = (
        audio_models.Channel.objects.all()
        .order_by("-id")
        .select_related(
            "owner",
        )
        .prefetch_related(
            Prefetch(
                "artist",
                queryset=(
                    music_models.Artist.objects.all()
                    .order_by("-id")
                    .select_related("attachment_cover", "channel")
                    .annotate(
                        _tracks_count=Count("artist_credit__tracks", distinct=True),
                        _albums_count=Count("artist_credit__albums", distinct=True),
                    )
                    .prefetch_related(music_views.TAG_PREFETCH)
                ),
            )
        )
    )
    serializer_class = serializers.ManageChannelSerializer
    filterset_class = filters.ManageChannelFilterSet
    required_scope = "instance:libraries"
    ordering_fields = ["creation_date", "name"]

    @extend_schema(operation_id="admin_get_channel_stats")
    @rest_decorators.action(methods=["get"], detail=True)
    def stats(self, request, *args, **kwargs):
        channel = self.get_object()
        tracks = music_models.Track.objects.filter(
            Q(artist_credit__artist=channel.artist)
            | Q(album__artist_credit__artist=channel.artist)
        )
        data = get_stats(tracks, channel, ignore_fields=["libraries", "channels"])
        data["follows"] = channel.subscriptions.filter(approved=True).count()
        return response.Response(data, status=200)

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context["description"] = self.action in ["retrieve", "create", "update"]
        return context
