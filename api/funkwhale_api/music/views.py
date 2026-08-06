import base64
import logging
import pathlib
import urllib.parse

import django.db.utils
from django.conf import settings
from django.core.cache import cache
from django.db import transaction
from django.db.models import Count, F, Prefetch, Sum
from django.utils import timezone
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import mixins, renderers
from rest_framework import settings as rest_settings
from rest_framework import views, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from funkwhale_api.common import decorators as common_decorators
from funkwhale_api.common import permissions as common_permissions
from funkwhale_api.common import preferences
from funkwhale_api.common import utils as common_utils
from funkwhale_api.common import views as common_views
from funkwhale_api.shares.permissions import (
    ShareOrScopePermission,
    resolve_active_share,
)
from funkwhale_api.tags.models import Tag, TaggedItem
from funkwhale_api.users.authentication import ScopedTokenAuthentication
from funkwhale_api.users.oauth import permissions as oauth_permissions

from . import filters, licenses, models, serializers, tasks, utils

logger = logging.getLogger(__name__)

TAG_PREFETCH = Prefetch(
    "tagged_items",
    queryset=TaggedItem.objects.all().select_related().order_by("tag__name"),
    to_attr="_prefetched_tagged_items",
)


def refetch_obj(obj, queryset):
    """
    Given an Artist/Album/Track instance, returns it as-is. Remote refetching
    is no longer supported since federation was removed.
    """
    return obj


class HandleInvalidSearch:
    def list(self, *args, **kwargs):
        try:
            return super().list(*args, **kwargs)
        except django.db.utils.ProgrammingError as e:
            if "in tsquery:" in str(e):
                return Response({"detail": "Invalid query"}, status=400)
            else:
                raise


class ArtistViewSet(
    HandleInvalidSearch,
    common_views.SkipFilterForGetObject,
    viewsets.ReadOnlyModelViewSet,
):
    queryset = (
        models.Artist.objects.all()
        .prefetch_related("attachment_cover")
        .prefetch_related(
            "channel",
            "artist_credit__tracks",
        )
        .order_by("-id")
    )
    serializer_class = serializers.ArtistWithAlbumsSerializer
    permission_classes = [oauth_permissions.ScopePermission]
    required_scope = "libraries"
    anonymous_policy = "setting"
    filterset_class = filters.ArtistFilter

    mutations = common_decorators.mutations_route(types=["update"])

    def get_object(self):
        obj = super().get_object()

        if (
            self.action == "retrieve"
            and self.request.GET.get("refresh", "").lower() == "true"
        ):
            obj = refetch_obj(obj, self.get_queryset())
        return obj

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context["description"] = self.action in ["retrieve", "create", "update"]
        return context

    def get_queryset(self):
        queryset = super().get_queryset()
        albums = (
            models.Album.objects.with_tracks_count()
            .select_related("attachment_cover")
            .prefetch_related("tracks", "artist_credit__artist")
        )
        albums = albums.annotate_playable_by_user(
            utils.get_user_from_request(self.request)
        )
        return queryset.prefetch_related(
            Prefetch("artist_credit__albums", queryset=albums),
            "artist_credit",
            TAG_PREFETCH,
        )


class AlbumViewSet(
    HandleInvalidSearch,
    common_views.SkipFilterForGetObject,
    mixins.CreateModelMixin,
    mixins.DestroyModelMixin,
    viewsets.ReadOnlyModelViewSet,
):
    queryset = (
        models.Album.objects.all()
        .order_by("-creation_date")
        .prefetch_related("artist_credit__artist__channel", "attachment_cover")
    )
    serializer_class = serializers.AlbumSerializer
    permission_classes = [oauth_permissions.ScopePermission]
    required_scope = "libraries"
    anonymous_policy = "setting"
    filterset_class = filters.AlbumFilter

    mutations = common_decorators.mutations_route(types=["update"])

    def get_object(self):
        obj = super().get_object()

        if (
            self.action == "retrieve"
            and self.request.GET.get("refresh", "").lower() == "true"
        ):
            obj = refetch_obj(obj, self.get_queryset())
        return obj

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context["description"] = self.action in [
            "retrieve",
            "create",
        ]
        context["user"] = self.request.user
        return context

    def get_queryset(self):
        queryset = super().get_queryset()
        if self.action in ["destroy"]:
            queryset = queryset.exclude(artist_credit__artist__channel=None).filter(
                artist_credit__artist__channel__owner=self.request.user
            )

        tracks = models.Track.objects.all().prefetch_related("album")
        tracks = tracks.annotate_playable_by_user(
            utils.get_user_from_request(self.request)
        )
        return queryset.prefetch_related(
            Prefetch("tracks", queryset=tracks), TAG_PREFETCH
        )

    def get_serializer_class(self):
        if self.action in ["create"]:
            return serializers.AlbumCreateSerializer
        return super().get_serializer_class()

    @transaction.atomic
    def perform_destroy(self, instance):
        models.Album.objects.filter(pk=instance.pk).delete()


class LibraryViewSet(
    mixins.CreateModelMixin,
    mixins.ListModelMixin,
    mixins.RetrieveModelMixin,
    mixins.UpdateModelMixin,
    mixins.DestroyModelMixin,
    viewsets.GenericViewSet,
):
    lookup_field = "uuid"
    queryset = (
        models.Library.objects.all()
        .filter(channel=None)
        .select_related("owner")
        .order_by("-creation_date")
        .annotate(_uploads_count=Count("uploads"))
        .annotate(_size=Sum("uploads__size"))
    )
    serializer_class = serializers.LibraryForOwnerSerializer
    permission_classes = [
        oauth_permissions.ScopePermission,
        common_permissions.OwnerPermission,
    ]
    filterset_class = filters.LibraryFilter
    required_scope = "libraries"
    anonymous_policy = "setting"
    owner_field = "owner"
    owner_checks = ["write"]

    def get_queryset(self):
        qs = super().get_queryset()
        # allow retrieving a single library by uuid if request.user isn't
        # the owner. Any other get should be from the owner only
        if self.action not in ["retrieve", "list"]:
            qs = qs.filter(owner=self.request.user)
        if self.action == "list":
            user = utils.get_user_from_request(self.request)
            qs = qs.viewable_by(user)

        return qs

    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)

    @transaction.atomic
    def perform_destroy(self, instance):
        instance.delete()

    # TODO quickfix, basically specifying the response would be None
    @extend_schema(responses=None)
    @action(
        methods=["get", "post", "delete"],
        detail=False,
        url_name="fs-import",
        url_path="fs-import",
    )
    @transaction.non_atomic_requests
    def fs_import(self, request, *args, **kwargs):
        if not request.user.is_authenticated:
            return Response({}, status=403)
        if not request.user.all_permissions["library"]:
            return Response({}, status=403)
        if request.method == "GET":
            path = request.GET.get("path", "")
            data = {
                "root": settings.MUSIC_DIRECTORY_PATH,
                "path": path,
                "import": None,
            }
            status = cache.get("fs-import:status", default=None)
            if status:
                data["import"] = {
                    "status": status,
                    "reference": cache.get("fs-import:reference"),
                    "logs": cache.get("fs-import:logs", default=[]),
                }
            try:
                data["content"] = utils.browse_dir(data["root"], data["path"])
            except (NotADirectoryError, ValueError, FileNotFoundError) as e:
                return Response({"detail": str(e)}, status=400)

            return Response(data)
        if request.method == "POST":
            if cache.get("fs-import:status", default=None) in [
                "pending",
                "started",
            ]:
                return Response({"detail": "An import is already running"}, status=400)

            data = request.data
            serializer = serializers.FSImportSerializer(
                data=data, context={"user": request.user}
            )
            serializer.is_valid(raise_exception=True)
            cache.set("fs-import:status", "pending")
            cache.set(
                "fs-import:reference", serializer.validated_data["import_reference"]
            )
            tasks.fs_import.delay(
                library_id=serializer.validated_data["library"].pk,
                path=serializer.validated_data["path"],
                import_reference=serializer.validated_data["import_reference"],
            )
            return Response(status=201)
        if request.method == "DELETE":
            cache.set("fs-import:status", "canceled")
            return Response(status=204)


class TrackViewSet(
    HandleInvalidSearch,
    common_views.SkipFilterForGetObject,
    mixins.DestroyModelMixin,
    viewsets.ReadOnlyModelViewSet,
):
    """
    A simple ViewSet for viewing and editing accounts.
    """

    queryset = (
        models.Track.objects.all()
        .for_nested_serialization()
        .prefetch_related("attachment_cover")
        .order_by("-creation_date")
    )
    serializer_class = serializers.TrackSerializer
    permission_classes = [oauth_permissions.ScopePermission]
    required_scope = "libraries"
    anonymous_policy = "setting"
    filterset_class = filters.TrackFilter
    mutations = common_decorators.mutations_route(types=["update"])

    def get_object(self):
        obj = super().get_object()

        if (
            self.action == "retrieve"
            and self.request.GET.get("refresh", "").lower() == "true"
        ):
            obj = refetch_obj(obj, self.get_queryset())
        return obj

    def get_queryset(self):
        queryset = super().get_queryset()
        if self.action in ["destroy"]:
            queryset = queryset.exclude(artist_credit__artist__channel=None).filter(
                artist_credit__artist__channel__owner=self.request.user
            )
        filter_favorites = self.request.GET.get("favorites", None)
        user = self.request.user
        if user.is_authenticated and filter_favorites == "true":
            queryset = queryset.filter(track_favorites__user=user)

        queryset = queryset.with_playable_uploads(
            utils.get_user_from_request(self.request)
        )
        return queryset.prefetch_related(TAG_PREFETCH)

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context["description"] = self.action in ["retrieve", "create", "update"]
        return context

    @transaction.atomic
    def perform_destroy(self, instance):
        instance.delete()


def strip_absolute_media_url(path):
    if (
        settings.MEDIA_URL.startswith("http://")
        or settings.MEDIA_URL.startswith("https://")
        and path.startswith(settings.MEDIA_URL)
    ):
        path = path.replace(settings.MEDIA_URL, "/media/", 1)
    return path


def _contained_inplace_path(path_str):
    """Validate an in-place absolute path is under MUSIC_DIRECTORY_PATH."""
    from funkwhale_api.music import utils as music_utils

    prefix = settings.MUSIC_DIRECTORY_PATH
    if not prefix:
        raise ValueError(
            "You need to specify MUSIC_DIRECTORY_SERVE_PATH and "
            "MUSIC_DIRECTORY_PATH to serve in-place imported files"
        )
    try:
        return music_utils.resolve_contained_path(path_str, prefix)
    except ValueError as exc:
        raise ValueError("In-place path is outside MUSIC_DIRECTORY_PATH") from exc


def get_file_path(audio_file):
    serve_path = settings.MUSIC_DIRECTORY_SERVE_PATH
    prefix = settings.MUSIC_DIRECTORY_PATH
    t = settings.REVERSE_PROXY_TYPE
    if t == "nginx":
        # we have to use the internal locations
        try:
            path = audio_file.url
        except AttributeError:
            # a path was given (in-place import)
            if not serve_path or not prefix:
                raise ValueError(
                    "You need to specify MUSIC_DIRECTORY_SERVE_PATH and "
                    "MUSIC_DIRECTORY_PATH to serve in-place imported files"
                )
            contained = _contained_inplace_path(audio_file)
            root = pathlib.Path(prefix).resolve()
            rel = str(contained.relative_to(root))
            path = "/music/" + rel.lstrip("/")
        path = strip_absolute_media_url(path)
        if path.startswith("http://") or path.startswith("https://"):
            protocol, remainder = path.split("://", 1)
            hostname, r_path = remainder.split("/", 1)
            r_path = urllib.parse.quote(r_path)
            path = protocol + "://" + hostname + "/" + r_path
            return (settings.PROTECT_FILES_PATH + "/media/" + path).encode("utf-8")
        # needed to serve files with % or ? chars
        path = urllib.parse.quote(path)
        return (settings.PROTECT_FILES_PATH + path).encode("utf-8")
    if t == "apache2":
        try:
            path = audio_file.path
        except AttributeError:
            # a path was given
            if not serve_path or not prefix:
                raise ValueError(
                    "You need to specify MUSIC_DIRECTORY_SERVE_PATH and "
                    "MUSIC_DIRECTORY_PATH to serve in-place imported files"
                )
            contained = _contained_inplace_path(audio_file)
            root = pathlib.Path(prefix).resolve()
            rel = str(contained.relative_to(root))
            path = str(pathlib.Path(serve_path) / rel)
        path = strip_absolute_media_url(path)
        return path.encode("utf-8")


def should_transcode(upload, format, max_bitrate=None):
    if not preferences.get("music__transcoding_enabled"):
        return False
    format_need_transcoding = True
    bitrate_need_transcoding = True
    if format is None:
        format_need_transcoding = False
    elif format not in utils.EXTENSION_TO_MIMETYPE:
        # format should match supported formats
        format_need_transcoding = False
    elif upload.mimetype is None:
        # upload should have a mimetype, otherwise we cannot transcode
        format_need_transcoding = False
    elif upload.mimetype == utils.EXTENSION_TO_MIMETYPE[format]:
        # requested format should be different than upload mimetype, otherwise
        # there is no need to transcode
        format_need_transcoding = False

    if max_bitrate is None:
        bitrate_need_transcoding = False
    elif not upload.bitrate:
        bitrate_need_transcoding = False
    elif upload.bitrate <= max_bitrate:
        bitrate_need_transcoding = False

    return format_need_transcoding or bitrate_need_transcoding


def get_content_disposition(filename):
    filename = f"filename*=UTF-8''{urllib.parse.quote(filename)}"
    return f"attachment; {filename}"


def record_downloads(f):
    def inner(*args, **kwargs):
        user = kwargs.get("user")
        wsgi_request = kwargs.pop("wsgi_request")
        upload = kwargs.get("upload")
        response = f(*args, **kwargs)
        if response.status_code >= 200 and response.status_code < 400:
            utils.increment_downloads_count(
                upload=upload, user=user, wsgi_request=wsgi_request
            )

        return response

    return inner


@record_downloads
def handle_serve(
    upload,
    user,
    format=None,
    max_bitrate=None,
    proxy_media=True,
    download=True,
    quality=None,
    allow_blocking_transcode=False,
):
    from . import quality as quality_mod
    from . import tasks as music_tasks

    f = upload
    # we update the accessed_date
    now = timezone.now()
    upload.accessed_date = now
    upload.save(update_fields=["accessed_date"])
    f = upload
    if f.audio_file:
        file_path = get_file_path(f.audio_file)

    elif f.source and f.source.startswith("file://"):
        file_path = get_file_path(f.source.replace("file://", "", 1))
    mt = f.mimetype

    resolved = quality_mod.resolve_serve_file(
        f, format=format, max_bitrate=max_bitrate, quality=quality
    )
    if resolved["pending"] and resolved["format"]:
        # Enqueue background encode; do not block the response for quality=.
        try:
            music_tasks.ensure_transcoded_version.delay(
                f.pk, resolved["format"], resolved["max_bitrate"]
            )
        except Exception:
            # Celery unavailable in some test/dev contexts — ignore.
            pass

    served_quality = resolved.get("served_quality") or "original"
    pending = bool(resolved.get("pending"))

    if should_transcode(f, resolved["format"], max_bitrate=resolved["max_bitrate"]):
        ready = quality_mod.find_transcoded_version(
            f, resolved["format"], max_bitrate=resolved["max_bitrate"]
        )
        if ready is not None:
            ready.accessed_date = now
            ready.save(update_fields=["accessed_date"])
            f = ready
            file_path = get_file_path(f.audio_file)
            mt = f.mimetype
            served_quality = quality_mod.normalize_quality(quality) or (
                resolved["format"] or "transcoded"
            )
            pending = False
        elif allow_blocking_transcode or (
            quality is None and (format is not None or max_bitrate is not None)
        ):
            # Legacy ?to= / Subsonic: create on demand if still missing.
            # Prefer ffmpeg via ensure_transcoded_version_sync.
            try:
                transcoded_version = quality_mod.ensure_transcoded_version_sync(
                    f, resolved["format"], max_bitrate=resolved["max_bitrate"]
                )
            except Exception:
                # Fall back to historical pydub path.
                transcoded_version = f.get_transcoded_version(
                    resolved["format"], max_bitrate=resolved["max_bitrate"]
                )
            transcoded_version.accessed_date = now
            transcoded_version.save(update_fields=["accessed_date"])
            f = transcoded_version
            file_path = get_file_path(f.audio_file)
            mt = f.mimetype
            served_quality = quality_mod.normalize_quality(quality) or (
                resolved["format"] or "transcoded"
            )
            pending = False
        else:
            # Non-blocking quality request: serve best ready fallback if any.
            fallback = resolved["file"]
            if fallback is not f and getattr(fallback, "audio_file", None):
                f = fallback
                file_path = get_file_path(f.audio_file)
                mt = getattr(f, "mimetype", None) or mt
                served_quality = resolved.get("served_quality") or "original"
    if not proxy_media and f.audio_file:
        # we simply issue a 302 redirect to the real URL
        response = Response(status=302)
        response["Location"] = f.audio_file.url
        return response
    if mt:
        response = Response(content_type=mt)
    else:
        response = Response()
    filename = f.filename
    mapping = {"nginx": "X-Accel-Redirect", "apache2": "X-Sendfile"}
    file_header = mapping[settings.REVERSE_PROXY_TYPE]
    response[file_header] = file_path
    if download:
        response["Content-Disposition"] = get_content_disposition(filename)
    if mt:
        response["Content-Type"] = mt

    # Expose what was actually served so clients can adapt.
    response["X-Audio-Quality"] = str(served_quality)
    if quality:
        response["X-Audio-Quality-Requested"] = str(
            quality_mod.normalize_quality(quality) or quality
        )
    if pending:
        response["X-Audio-Quality-Pending"] = "1"

    return response


class ListenMixin(mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    queryset = models.Track.objects.all()
    serializer_class = serializers.TrackSerializer
    authentication_classes = (
        rest_settings.api_settings.DEFAULT_AUTHENTICATION_CLASSES
        + [ScopedTokenAuthentication]
    )
    # ShareOrScopePermission accepts valid ?share= tokens even when
    # common__api_authentication_required is True; invalid share tokens fail closed.
    permission_classes = [ShareOrScopePermission]
    required_scope = "libraries"
    anonymous_policy = "setting"
    lookup_field = "uuid"
    throttling_scopes = {
        "retrieve": {
            "authenticated": "authenticated-retrieve",
            "anonymous": "share-stream",
        },
    }

    @extend_schema(
        operation_id="get_track_file",
        summary="Stream or download a track audio file",
        description=(
            "Authorize and serve progressive audio for a track. "
            "Django checks library ACLs, then hands the body off via "
            "X-Accel-Redirect / X-Sendfile (or a 302 when PROXY_MEDIA is off).\n\n"
            "Prefer `quality=` for multi-bitrate progressive streaming. "
            "When the requested quality is not ready yet, the server serves "
            "the best available fallback and enqueues a background encode "
            "(`X-Audio-Quality-Pending: 1`). Response headers:\n"
            "- `X-Audio-Quality`: tier actually served\n"
            "- `X-Audio-Quality-Requested`: requested tier (if any)\n"
            "- `X-Audio-Quality-Pending`: set when a better derivative is building\n\n"
            "Legacy params `to` and `max_bitrate` remain supported (may block "
            "on cold encode). Playback clients should pass `download=false`."
        ),
        parameters=[
            OpenApiParameter(
                name="quality",
                type=str,
                location=OpenApiParameter.QUERY,
                required=False,
                enum=["original", "high", "medium", "low"],
                description=(
                    "Progressive quality ladder tier. Maps to server encode "
                    "profiles (high≈256k MP3, medium≈128k, low≈96k). "
                    "Non-blocking when the derivative is missing."
                ),
            ),
            OpenApiParameter(
                name="to",
                type=str,
                location=OpenApiParameter.QUERY,
                required=False,
                description=(
                    "Legacy target format extension (e.g. mp3, ogg). "
                    "May block on first encode if no cached version exists."
                ),
            ),
            OpenApiParameter(
                name="max_bitrate",
                type=int,
                location=OpenApiParameter.QUERY,
                required=False,
                description=(
                    "Legacy max bitrate in kbps (clamped 0–320). "
                    "Combined with `to` for on-demand transcoding."
                ),
            ),
            OpenApiParameter(
                name="download",
                type=str,
                location=OpenApiParameter.QUERY,
                required=False,
                enum=["true", "false"],
                description=(
                    "When true (default), sets Content-Disposition: attachment. "
                    "Use false for inline progressive playback."
                ),
            ),
            OpenApiParameter(
                name="upload",
                type=str,
                location=OpenApiParameter.QUERY,
                required=False,
                description="Optional Upload UUID to pin a specific file.",
            ),
            OpenApiParameter(
                name="token",
                type=str,
                location=OpenApiParameter.QUERY,
                required=False,
                description=(
                    "Scoped listen token for clients that cannot send "
                    "Authorization (e.g. browser media elements)."
                ),
            ),
            OpenApiParameter(
                name="share",
                type=str,
                location=OpenApiParameter.QUERY,
                required=False,
                description=(
                    "Secret share-link token granting listen access to a "
                    "specific album or playlist only."
                ),
            ),
        ],
        responses={
            200: {
                "description": "Audio bytes (via reverse-proxy sendfile).",
                "content": {
                    "audio/*": {"schema": {"type": "string", "format": "binary"}}
                },
            },
            302: {"description": "Redirect to storage URL when PROXY_MEDIA is false."},
            404: {"description": "Track or playable upload not found."},
            503: {"description": "Track unavailable."},
        },
    )
    def retrieve(self, request, *args, **kwargs):
        config = {
            "explicit_file": request.GET.get("upload"),
            "download": request.GET.get("download", "true").lower() == "true",
            "format": request.GET.get("to"),
            "max_bitrate": request.GET.get("max_bitrate"),
            "quality": request.GET.get("quality"),
        }
        track = self.get_object()
        return handle_stream(track, request, **config)


def handle_stream(
    track, request, download, explicit_file, format, max_bitrate, quality=None
):
    share_link = getattr(request, "share_link", None)
    if share_link is None:
        share_token = request.GET.get("share")
        if share_token:
            share_link = resolve_active_share(share_token)

    if share_link is not None:
        # Secret share: membership + sharer's playable uploads only.
        # Re-resolve so revoked/expired/disabled-owner tokens fail even if a
        # stale request.share_link was set earlier in the permission phase.
        fresh = resolve_active_share(share_link.token)
        if fresh is None:
            return Response(status=404)
        share_link = fresh
        if not share_link.includes_track(track):
            return Response(status=404)
        # Same relation paths as the normal stream branch (artist_credit M2M,
        # not a legacy Album.artist / Track.artist FK).
        queryset = track.uploads.prefetch_related(
            "track__album__artist_credit__artist",
            "track__artist_credit__artist",
        )
        if explicit_file:
            queryset = queryset.filter(uuid=explicit_file)
        queryset = queryset.playable_by(share_link.owner)
        queryset = queryset.order_by(F("audio_file").desc(nulls_last=True))
        upload = queryset.first()
        if not upload:
            return Response(status=404)
        try:
            max_bitrate = min(max(int(max_bitrate), 0), 320) or None
        except (TypeError, ValueError):
            max_bitrate = None
        if max_bitrate:
            max_bitrate = max_bitrate * 1000
        # Share links are listen-only: never force Content-Disposition attachment.
        return handle_serve(
            upload=upload,
            user=share_link.owner,
            format=format,
            max_bitrate=max_bitrate,
            proxy_media=settings.PROXY_MEDIA,
            download=False,
            quality=quality,
            allow_blocking_transcode=quality is None,
            wsgi_request=request._request,
        )

    actor = utils.get_user_from_request(request)
    queryset = track.uploads.prefetch_related(
        "track__album__artist_credit__artist", "track__artist_credit__artist"
    )
    if explicit_file:
        queryset = queryset.filter(uuid=explicit_file)
    queryset = queryset.playable_by(actor)
    queryset = queryset.order_by(F("audio_file").desc(nulls_last=True))
    upload = queryset.first()
    if not upload:
        return Response(status=404)

    try:
        max_bitrate = min(max(int(max_bitrate), 0), 320) or None
    except (TypeError, ValueError):
        max_bitrate = None

    if max_bitrate:
        max_bitrate = max_bitrate * 1000
    return handle_serve(
        upload=upload,
        user=request.user,
        format=format,
        max_bitrate=max_bitrate,
        proxy_media=settings.PROXY_MEDIA,
        download=download,
        quality=quality,
        # quality= requests never block on cold encode; legacy to=/bitrate may.
        allow_blocking_transcode=quality is None,
        wsgi_request=request._request,
    )


class AudioRenderer(renderers.JSONRenderer):
    media_type = "audio/*"


class ListenViewSet(ListenMixin):
    renderer_classes = [AudioRenderer]


class MP3Renderer(renderers.JSONRenderer):
    format = "mp3"
    media_type = "audio/mpeg"


class StreamViewSet(ListenMixin):
    renderer_classes = [MP3Renderer]

    @extend_schema(
        operation_id="get_track_stream",
        summary="Stream a track as MP3",
        description=(
            "Convenience endpoint that forces MP3 (`to=mp3`) with "
            "`download=false`. Prefer `/listen/{uuid}/?quality=…` for the "
            "multi-quality progressive ladder."
        ),
        responses={
            200: {
                "description": "MP3 audio bytes.",
                "content": {
                    "audio/mpeg": {"schema": {"type": "string", "format": "binary"}}
                },
            }
        },
    )
    def retrieve(self, request, *args, **kwargs):
        config = {
            "explicit_file": None,
            "download": False,
            "format": "mp3",
            "max_bitrate": None,
            "quality": None,
        }
        track = self.get_object()
        return handle_stream(track, request, **config)


class UploadViewSet(
    mixins.ListModelMixin,
    mixins.CreateModelMixin,
    mixins.RetrieveModelMixin,
    mixins.UpdateModelMixin,
    mixins.DestroyModelMixin,
    viewsets.GenericViewSet,
):
    lookup_field = "uuid"
    queryset = (
        models.Upload.objects.all()
        .order_by("-creation_date")
        .prefetch_related(
            "library__owner",
            "track__artist_credit__artist",
            "track__album__artist_credit__artist",
            "track__attachment_cover",
        )
    )
    serializer_class = serializers.UploadForOwnerSerializer
    permission_classes = [
        oauth_permissions.ScopePermission,
        common_permissions.OwnerPermission,
    ]
    required_scope = "libraries"
    anonymous_policy = "setting"
    owner_field = "library.owner"
    owner_checks = ["write"]
    filterset_class = filters.UploadFilter
    ordering_fields = (
        "creation_date",
        "import_date",
        "bitrate",
        "size",
        "artist_credit__artist__name",
    )

    def get_queryset(self):
        qs = super().get_queryset()
        if self.action in ["update", "partial_update"]:
            # prevent updating an upload that is already processed
            qs = qs.filter(import_status="draft")
        if self.action != "retrieve":
            qs = qs.filter(library__owner=self.request.user)
        else:
            user = utils.get_user_from_request(self.request)
            qs = qs.playable_by(user)
        return qs

    @extend_schema(
        responses=tasks.metadata.TrackMetadataSerializer(),
        operation_id="get_upload_metadata",
    )
    @action(methods=["get"], detail=True, url_path="audio-file-metadata")
    def audio_file_metadata(self, request, *args, **kwargs):
        upload = self.get_object()
        try:
            m = tasks.metadata.Metadata(upload.get_audio_file())
        except FileNotFoundError:
            return Response({"detail": "File not found"}, status=500)
        serializer = tasks.metadata.TrackMetadataSerializer(
            data=m, context={"strict": False}
        )
        if not serializer.is_valid():
            return Response(serializer.errors, status=500)
        payload = serializer.validated_data
        cover_data = payload.get(
            "cover_data", payload.get("album", {}).get("cover_data", {})
        )
        if cover_data and "content" in cover_data:
            cover_data["content"] = base64.b64encode(cover_data["content"])
        return Response(payload, status=200)

    @action(methods=["post"], detail=False)
    def action(self, request, *args, **kwargs):
        queryset = self.get_queryset()
        serializer = serializers.UploadActionSerializer(request.data, queryset=queryset)
        serializer.is_valid(raise_exception=True)
        result = serializer.save()
        return Response(result, status=200)

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context["user"] = self.request.user
        return context

    def perform_create(self, serializer):
        upload = serializer.save()
        if upload.import_status == "pending":
            common_utils.on_commit(tasks.process_upload.delay, upload_id=upload.pk)

    def perform_update(self, serializer):
        upload = serializer.save()
        if upload.import_status == "pending":
            common_utils.on_commit(tasks.process_upload.delay, upload_id=upload.pk)

    @transaction.atomic
    def perform_destroy(self, instance):
        instance.delete()


class Search(views.APIView):
    max_results = 3
    permission_classes = [oauth_permissions.ScopePermission]
    required_scope = "libraries"
    anonymous_policy = "setting"

    @extend_schema(
        operation_id="get_search_results", responses=serializers.SearchResultSerializer
    )
    def get(self, request, *args, **kwargs):
        query = request.GET.get("query", request.GET.get("q", "")) or ""
        query = query.strip()
        if not query:
            return Response({"detail": "empty query"}, status=400)
        try:
            results = {
                "artists": self.get_artists(query),
                "tracks": self.get_tracks(query),
                "albums": self.get_albums(query),
                "tags": self.get_tags(query),
            }
        except django.db.utils.ProgrammingError as e:
            if "in tsquery:" in str(e):
                return Response({"detail": "Invalid query"}, status=400)
            else:
                raise

        return Response(serializers.SearchResultSerializer(results).data, status=200)

    def get_tracks(self, query):
        query_obj = utils.get_fts_query(
            query,
            fts_fields=[
                "body_text",
                "album__body_text",
                "artist_credit__artist__body_text",
            ],
            model=models.Track,
        )
        qs = (
            models.Track.objects.all()
            .filter(query_obj)
            .prefetch_related(
                "artist_credit__artist",
                Prefetch(
                    "album",
                    queryset=models.Album.objects.select_related(
                        "attachment_cover"
                    ).prefetch_related("artist_credit__artist", "tracks"),
                ),
            )
        )
        return common_utils.order_for_search(qs, "title")[: self.max_results]

    def get_albums(self, query):
        query_obj = utils.get_fts_query(
            query,
            fts_fields=["body_text", "artist_credit__artist__body_text"],
            model=models.Album,
        )
        qs = (
            models.Album.objects.all()
            .filter(query_obj)
            .select_related("attachment_cover")
            .prefetch_related("artist_credit__artist")
            .prefetch_related("tracks__artist_credit__artist")
        )
        return common_utils.order_for_search(qs, "title")[: self.max_results]

    def get_artists(self, query):
        query_obj = utils.get_fts_query(query, model=models.Artist)
        qs = (
            models.Artist.objects.all()
            .filter(query_obj)
            .with_albums()
            .prefetch_related("channel")
        )
        return common_utils.order_for_search(qs, "name")[: self.max_results]

    def get_tags(self, query):
        search_fields = ["name__unaccent"]
        query_obj = utils.get_query(query, search_fields)
        qs = Tag.objects.all().filter(query_obj)
        return common_utils.order_for_search(qs, "name")[: self.max_results]


class LicenseViewSet(viewsets.ReadOnlyModelViewSet):
    permission_classes = [oauth_permissions.ScopePermission]
    required_scope = "libraries"
    anonymous_policy = "setting"
    serializer_class = serializers.LicenseSerializer
    queryset = models.License.objects.all().order_by("code")
    lookup_value_regex = ".*"
    max_page_size = 1000

    def get_queryset(self):
        # ensure our licenses are up to date in DB
        licenses.load(licenses.LICENSES)
        return super().get_queryset()

    def get_serializer(self, *args, **kwargs):
        if len(args) == 0:
            return super().get_serializer(*args, **kwargs)

        # our serializer works with license dict, not License instances
        # so we pass those instead
        instance_or_qs = args[0]
        try:
            first_arg = instance_or_qs.conf
        except AttributeError:
            first_arg = [i.conf for i in instance_or_qs if i.conf]
        return super().get_serializer(*((first_arg,) + args[1:]), **kwargs)


class OembedView(views.APIView):
    permission_classes = [oauth_permissions.ScopePermission]
    required_scope = "libraries"
    anonymous_policy = "setting"
    serializer_class = serializers.OembedSerializer

    def get(self, request, *args, **kwargs):
        serializer = serializers.OembedSerializer(data=request.GET)
        serializer.is_valid(raise_exception=True)
        embed_data = serializer.save()
        return Response(embed_data)
