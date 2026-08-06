import datetime

from django.utils import timezone
from rest_framework import serializers

from funkwhale_api.music import models as music_models
from funkwhale_api.music import serializers as music_serializers
from funkwhale_api.playlists import serializers as playlist_serializers

from . import models, permissions


class ShareLinkSerializer(serializers.ModelSerializer):
    """Owner-facing representation (includes secret token and absolute URL)."""

    url = serializers.SerializerMethodField()
    expires_in_days = serializers.IntegerField(
        write_only=True, required=False, allow_null=True, min_value=1, max_value=3650
    )
    # Explicit choices so clients cannot invent object_type values.
    object_type = serializers.ChoiceField(choices=models.ShareLink.OBJECT_TYPES)
    object_id = serializers.IntegerField(min_value=1)
    label = serializers.CharField(
        required=False, allow_blank=True, max_length=100, default=""
    )

    class Meta:
        model = models.ShareLink
        fields = (
            "uuid",
            "token",
            "url",
            "object_type",
            "object_id",
            "label",
            "creation_date",
            "expiration_date",
            "expires_in_days",
        )
        read_only_fields = (
            "uuid",
            "token",
            "url",
            "creation_date",
            "expiration_date",
        )
        # Never accept client-supplied secrets or ownership.
        extra_kwargs = {
            "token": {"read_only": True},
        }

    def get_url(self, obj) -> str:
        return obj.get_absolute_url()

    def validate(self, attrs):
        object_type = attrs.get("object_type")
        object_id = attrs.get("object_id")
        request = self.context["request"]
        # Raises 404 / PermissionDenied
        permissions.assert_can_share(request.user, object_type, object_id)
        return attrs

    def create(self, validated_data):
        expires_in_days = validated_data.pop("expires_in_days", None)
        # Always bind to the authenticated user — ignore any injected owner.
        owner = self.context["request"].user
        validated_data.pop("owner", None)
        validated_data.pop("token", None)
        expiration_date = None
        if expires_in_days:
            expiration_date = timezone.now() + datetime.timedelta(days=expires_in_days)
        return models.ShareLink.objects.create(
            owner=owner,
            expiration_date=expiration_date,
            **validated_data,
        )


class ShareTrackSerializer(serializers.Serializer):
    """Minimal track payload for public share resolve.

    Mirrors the core fields clients need for playback. Artists use the
    multi-credit ``artist_credit`` shape (there is no Track.artist FK).
    """

    id = serializers.IntegerField()
    title = serializers.CharField()
    position = serializers.IntegerField(allow_null=True)
    disc_number = serializers.IntegerField(allow_null=True)
    artist_credit = music_serializers.ArtistCreditSerializer(many=True)
    album = music_serializers.TrackAlbumSerializer(allow_null=True)
    cover = music_serializers.CoverField(allow_null=True)
    listen_url = serializers.SerializerMethodField()
    is_playable = serializers.SerializerMethodField()
    # Client Track.duration is derived from uploads[0].duration.
    uploads = serializers.SerializerMethodField()

    def get_listen_url(self, obj) -> str:
        return obj.listen_url

    def _playable_uploads(self, obj):
        """
        Only uploads the share owner can play.

        Never fall back to arbitrary finished uploads — that would leak
        private library file UUIDs / listen URLs the sharer cannot access.
        """
        uploads = getattr(obj, "playable_uploads", None)
        if uploads is None:
            return []
        return list(uploads)

    def get_uploads(self, obj):
        uploads = self._playable_uploads(obj)
        if not uploads:
            return []
        upload = uploads[0]
        return [
            {
                "uuid": str(upload.uuid),
                "duration": upload.duration,
                "mimetype": upload.mimetype,
                "listen_url": upload.listen_url,
            }
        ]

    def get_is_playable(self, obj) -> bool:
        return bool(self._playable_uploads(obj))


class PublicShareSerializer(serializers.Serializer):
    """Payload returned to unauthenticated visitors holding a secret token."""

    object_type = serializers.CharField()
    object_id = serializers.IntegerField()
    expiration_date = serializers.DateTimeField(allow_null=True)
    item = serializers.SerializerMethodField()
    tracks = serializers.SerializerMethodField()

    def get_item(self, link: models.ShareLink):
        obj = link.get_object()
        if obj is None:
            return None
        if link.object_type == models.ShareLink.OBJECT_ALBUM:
            # Re-fetch with relations AlbumSerializer needs.
            album = (
                music_models.Album.objects.filter(pk=obj.pk)
                .select_related("attachment_cover")
                .prefetch_related("artist_credit__artist")
                .first()
            )
            if album is None:
                return None
            return music_serializers.AlbumSerializer(album, context=self.context).data
        if link.object_type == models.ShareLink.OBJECT_PLAYLIST:
            return playlist_serializers.PlaylistSerializer(
                obj, context=self.context
            ).data
        return None

    def get_tracks(self, link: models.ShareLink):
        from django.db.models import Prefetch

        owner = link.owner

        raw = link.track_queryset()
        if isinstance(raw, list):
            track_ids = [t.pk for t in raw]
            qs = music_models.Track.objects.filter(pk__in=track_ids)
        else:
            qs = raw
            track_ids = None

        # Track/Album use artist_credit M2M — not a direct artist FK.
        qs = qs.select_related(
            "album",
            "album__attachment_cover",
            "attachment_cover",
        ).prefetch_related(
            "artist_credit__artist",
            "album__artist_credit__artist",
        )
        playable = music_models.Upload.objects.playable_by(owner)
        qs = qs.prefetch_related(
            Prefetch(
                "uploads",
                queryset=playable.select_related("library"),
                to_attr="playable_uploads",
            )
        )

        if track_ids is not None:
            by_id = {t.pk: t for t in qs}
            tracks = [by_id[i] for i in track_ids if i in by_id]
        else:
            tracks = list(qs)

        # Attach playlist index as position for playlists
        if link.object_type == models.ShareLink.OBJECT_PLAYLIST:
            for idx, t in enumerate(tracks):
                if t.position is None:
                    t.position = idx

        return ShareTrackSerializer(tracks, many=True, context=self.context).data
