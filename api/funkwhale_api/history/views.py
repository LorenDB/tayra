from django.core.exceptions import ValidationError
from django.db.models import Prefetch
from django.http import Http404
from django.utils import timezone
from drf_spectacular.utils import OpenApiParameter, extend_schema, extend_schema_view
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError as DRFValidationError
from rest_framework.response import Response

from config import plugins
from funkwhale_api.activity import record
from funkwhale_api.common import fields, permissions
from funkwhale_api.music import utils as music_utils
from funkwhale_api.music.models import Track
from funkwhale_api.users.oauth import permissions as oauth_permissions

from . import bulk as bulk_module
from . import filters, models, serializers, stats


@extend_schema_view(
    list=extend_schema(operation_id="list_listenings"),
    retrieve=extend_schema(operation_id="get_listening"),
    create=extend_schema(
        operation_id="create_listening",
        description=(
            "Create a listening. Supports rich fields (duration_seconds, "
            "source_device, client_session_id). Idempotent re-POST with the same "
            "client_session_id returns 200 and may update duration. "
            "source_device must be pre-registered. Response is flat PKs "
            "(not nested track/user from list/retrieve)."
        ),
        request=serializers.ListeningWriteSerializer,
        responses={
            200: serializers.ListeningCreateResponseSerializer,
            201: serializers.ListeningCreateResponseSerializer,
        },
    ),
    partial_update=extend_schema(
        operation_id="patch_listening",
        description=(
            "Update duration_seconds (monotonic max) and/or source_device on a "
            "listening by server id."
        ),
        request=serializers.ListeningUpdateSerializer,
        responses={200: serializers.ListeningUpdateResponseSerializer},
    ),
)
class ListeningViewSet(
    mixins.CreateModelMixin,
    mixins.ListModelMixin,
    mixins.RetrieveModelMixin,
    mixins.UpdateModelMixin,
    viewsets.GenericViewSet,
):
    serializer_class = serializers.ListeningSerializer
    queryset = models.Listening.objects.all().select_related(
        "user__avatar_attachment",
        "source_device",
    )

    permission_classes = [
        oauth_permissions.ScopePermission,
        permissions.OwnerPermission,
    ]
    required_scope = "listenings"
    anonymous_policy = "setting"
    owner_checks = ["write"]
    filterset_class = filters.ListeningFilter
    # Explicit allow-list (model field is creation_date, not "created").
    ordering_fields = ("creation_date", "id")
    ordering = ("-creation_date",)
    # Design documents PATCH only (not full PUT) for duration updates.
    http_method_names = ["get", "post", "patch", "head", "options"]
    throttling_scopes = {
        "partial_update": {"authenticated": "authenticated-listening-update"},
        "by_session": {"authenticated": "authenticated-listening-update"},
        "bulk": {"authenticated": "authenticated-listenings-bulk"},
    }

    def get_serializer_class(self):
        if getattr(self, "action", None) == "bulk":
            return serializers.ListeningBulkSerializer
        if self.request.method.lower() in ["head", "get", "options"]:
            return serializers.ListeningSerializer
        if self.request.method.lower() == "patch" or getattr(self, "action", None) in (
            "partial_update",
            "update",
            "by_session",
        ):
            return serializers.ListeningUpdateSerializer
        return serializers.ListeningWriteSerializer

    def perform_create(self, serializer):
        # serializer.save() / create() must set serializer.instance._rich_created
        serializer.save()
        if not getattr(serializer.instance, "_rich_created", True):
            # Idempotent session re-POST: duration may have been updated; no plugins/activity
            return
        plugins.trigger_hook(
            plugins.LISTENING_CREATED,
            listening=serializer.instance,
            confs=plugins.get_confs(self.request.user),
        )
        record.send(serializer.instance)

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        headers = self.get_success_headers(serializer.data)
        created = getattr(serializer.instance, "_rich_created", True)
        return Response(
            serializer.data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
            headers=headers,
        )

    @extend_schema(
        operation_id="patch_listening_by_session",
        description=(
            "PATCH duration/device by client_session_id (owner-scoped). "
            "Primary mobile path after create when the client retained only the "
            "session UUID (not the server integer id)."
        ),
        request=serializers.ListeningUpdateSerializer,
        responses={200: serializers.ListeningUpdateResponseSerializer},
        parameters=[
            OpenApiParameter(
                name="client_session_id",
                type=str,
                location=OpenApiParameter.PATH,
                required=True,
                description="Client-generated session UUID from the create body.",
            ),
        ],
    )
    @action(
        methods=["patch"],
        detail=False,
        url_path=r"by-session/(?P<client_session_id>[^/.]+)",
        url_name="by-session",
    )
    def by_session(self, request, client_session_id=None, *args, **kwargs):
        """
        PATCH duration/device by client_session_id (owner-scoped).

        Primary mobile path after create when the client retained only the
        session UUID (not the server integer id).
        """
        if not request.user.is_authenticated:
            raise Http404
        try:
            listening = self.get_queryset().get(
                user=request.user,
                client_session_id=client_session_id,
            )
        except (
            models.Listening.DoesNotExist,
            ValueError,
            TypeError,
            ValidationError,
        ):
            raise Http404

        serializer = self.get_serializer(listening, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)

    def get_queryset(self):
        queryset = super().get_queryset()
        queryset = queryset.filter(
            fields.privacy_level_query(self.request.user, "user__privacy_level")
        )
        # List/retrieve default to rich-only so stock scrobbles (often missing
        # nested track payloads clients expect) never reach Tayra. Opt out with
        # ?rich_only=false. Stats always use .rich() server-side.
        if self.action in ("list", "retrieve"):
            rich_param = self.request.query_params.get("rich_only", "true")
            if str(rich_param).lower() not in ("0", "false", "no"):
                queryset = queryset.rich()
        tracks = Track.objects.with_playable_uploads(
            music_utils.get_user_from_request(self.request)
        ).prefetch_related(
            "artist_credit__artist",
            "artist_credit__artist__attachment_cover",
            "album__artist_credit__artist",
        )
        return queryset.prefetch_related(Prefetch("track", queryset=tracks))

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context["user"] = self.request.user
        return context

    @extend_schema(
        operation_id="bulk_create_listenings",
        description=(
            "Bulk import listenings (owner-only). Modes: enrich_or_create "
            "(default), create_only. Never fires plugins or activity. "
            "Max batch size applies; partial success with per-row errors."
        ),
        request=serializers.ListeningBulkSerializer,
        responses={200: serializers.ListeningBulkResultSerializer},
    )
    @action(methods=["post"], detail=False)
    def bulk(self, request, *args, **kwargs):
        """
        Bulk import listenings (owner-only). Modes: enrich_or_create (default),
        create_only. Never fires plugins or activity.
        """
        if not request.user.is_authenticated:
            return Response(status=status.HTTP_401_UNAUTHORIZED)

        serializer = serializers.ListeningBulkSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        result = bulk_module.process_bulk_listenings(
            request.user,
            mode=data.get("mode", "enrich_or_create"),
            items=data["items"],
            dedup_window_seconds=data.get(
                "dedup_window_seconds",
                bulk_module.DEFAULT_DEDUP_WINDOW_SECONDS,
            ),
        )
        return Response(
            serializers.ListeningBulkResultSerializer(result).data,
            status=status.HTTP_200_OK,
        )

    @extend_schema(
        operation_id="get_listening_stats",
        description=(
            "Year-in-review aggregates for the authenticated user only. "
            "Returns totals, unique counts, top tracks/artists/albums, monthly "
            "breakdown, and per-device aggregates."
        ),
        parameters=[
            OpenApiParameter(
                name="year",
                type=int,
                location=OpenApiParameter.QUERY,
                required=False,
                description="Calendar year (default: current year).",
            ),
            OpenApiParameter(
                name="limit",
                type=int,
                location=OpenApiParameter.QUERY,
                required=False,
                description="Top-N size (default 10, max 50).",
            ),
        ],
        responses={200: serializers.ListeningStatsSerializer},
    )
    @action(detail=False, methods=["get"], url_path="stats")
    def stats(self, request, *args, **kwargs):
        """
        Year-in-review aggregates for the authenticated user only (K6/K14).

        Query params:
        - year: calendar year (default: current year)
        - limit: top-N size (default 10, max 50)
        """
        if not request.user.is_authenticated:
            return Response(
                {"detail": "Authentication credentials were not provided."},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        year, year_errors = self._parse_stats_year(request)
        limit, limit_errors = self._parse_stats_limit(request)
        errors = {}
        if year_errors:
            errors["year"] = year_errors
        if limit_errors:
            errors["limit"] = limit_errors
        if errors:
            raise DRFValidationError(errors)

        payload = stats.compute_listening_stats(
            user=request.user, year=year, limit=limit
        )
        # Serialize through schema so OpenAPI keys stay coupled to the wire format.
        return Response(
            serializers.ListeningStatsSerializer(payload).data,
            status=status.HTTP_200_OK,
        )

    @staticmethod
    def _parse_stats_year(request):
        """Return (year, error_list_or_None)."""
        raw = request.query_params.get("year")
        if raw is None or raw == "":
            return timezone.now().year, None
        try:
            year = int(raw)
        except (TypeError, ValueError):
            return None, [
                {"code": "invalid", "detail": "year must be an integer"},
            ]
        if year < 1970 or year > 2100:
            return None, [
                {
                    "code": "invalid",
                    "detail": "year must be between 1970 and 2100",
                }
            ]
        return year, None

    @staticmethod
    def _parse_stats_limit(request):
        """Return (limit, error_list_or_None)."""
        raw = request.query_params.get("limit")
        if raw is None or raw == "":
            return 10, None
        try:
            limit = int(raw)
        except (TypeError, ValueError):
            return None, [
                {"code": "invalid", "detail": "limit must be an integer"},
            ]
        if limit < 1 or limit > 50:
            return None, [
                {
                    "code": "invalid",
                    "detail": "limit must be between 1 and 50",
                }
            ]
        return limit, None
