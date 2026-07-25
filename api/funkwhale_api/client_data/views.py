import logging

from django.contrib.auth import get_user_model
from django.db import IntegrityError, transaction
from django.db.models import Q
from django.utils import timezone
from drf_spectacular.utils import OpenApiParameter, extend_schema, extend_schema_view
from rest_framework import mixins, serializers as drf_serializers, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response

from funkwhale_api.common import permissions
from funkwhale_api.music.models import Track
from funkwhale_api.users.oauth import permissions as oauth_permissions

from . import filters, models, serializers
from .serializers import MAX_KEYS_PER_SCOPE, raise_coded

logger = logging.getLogger(__name__)


@extend_schema_view(
    list=extend_schema(
        operation_id="list_client_devices",
        description=(
            "List the authenticated user's client devices. "
            "Feature probe: 404 means this pod does not support client_data."
        ),
    ),
    create=extend_schema(
        operation_id="upsert_client_device",
        description=(
            "Upsert a client device by (user, uuid). Refreshes name/last_seen_at "
            "and reactivates soft-deleted devices. Returns 201 on create, 200 on update."
        ),
        request=serializers.ClientDeviceSerializer,
        responses={
            200: serializers.ClientDeviceSerializer,
            201: serializers.ClientDeviceSerializer,
        },
    ),
    partial_update=extend_schema(
        operation_id="patch_client_device",
        description="Rename a device or set is_active (reactivate).",
        request=serializers.ClientDeviceSerializer,
        responses={200: serializers.ClientDeviceSerializer},
    ),
    destroy=extend_schema(
        operation_id="delete_client_device",
        description="Soft-delete a device (is_active=False). Listenings retain the FK.",
        responses={204: None},
    ),
)
class ClientDeviceViewSet(
    mixins.CreateModelMixin,
    mixins.ListModelMixin,
    mixins.UpdateModelMixin,
    mixins.DestroyModelMixin,
    viewsets.GenericViewSet,
):
    """Owner-only registry of client devices (installs)."""

    serializer_class = serializers.ClientDeviceSerializer
    queryset = models.ClientDevice.objects.all()
    permission_classes = [
        oauth_permissions.ScopePermission,
        permissions.OwnerPermission,
    ]
    required_scope = "client_data"
    # Authenticated only; no anonymous access (not in ANONYMOUS_SCOPES).
    anonymous_policy = False
    owner_checks = ["write"]
    lookup_field = "uuid"
    # Design documents PATCH only (not full PUT replace) for detail writes.
    http_method_names = ["get", "post", "patch", "delete", "head", "options"]

    def get_queryset(self):
        # Owner-only: never expose another user's devices.
        if not self.request.user.is_authenticated:
            return models.ClientDevice.objects.none()
        return models.ClientDevice.objects.filter(user=self.request.user)

    def create(self, request, *args, **kwargs):
        """Upsert by (user, uuid): refresh name/last_seen_at; reactivate if soft-deleted."""
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        defaults = {
            "name": data["name"],
            "client_id": data["client_id"],
            "last_seen_at": timezone.now(),
            "is_active": True,
        }
        # Only overwrite client_version when the client sends it (omit preserves).
        if "client_version" in data:
            defaults["client_version"] = data["client_version"]
        device, created = models.ClientDevice.objects.update_or_create(
            user=request.user,
            uuid=data["uuid"],
            defaults=defaults,
        )
        out = self.get_serializer(device)
        headers = self.get_success_headers(out.data)
        return Response(
            out.data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
            headers=headers,
        )

    def perform_destroy(self, instance):
        """Soft-delete: set is_active=False (listenings retain FK)."""
        instance.is_active = False
        instance.save(update_fields=["is_active"])


class ClientPreferenceViewSet(viewsets.GenericViewSet):
    """
    Owner-only namespaced client preferences.

    GET  /api/v1/client-preferences/?client_id=…&device_uuid=…
    PUT  /api/v1/client-preferences/  {client_id, device_uuid, preferences, mode}

    PUT returns only the written scope (account *or* device rows). Effective
    config for a device is GET with ``device_uuid`` (account ∪ device, device wins).
    """

    queryset = models.ClientPreference.objects.all()
    permission_classes = [
        oauth_permissions.ScopePermission,
        permissions.OwnerPermission,
    ]
    required_scope = "client_data"
    anonymous_policy = False
    owner_checks = ["write"]
    pagination_class = None
    http_method_names = ["get", "put", "head", "options"]

    def get_queryset(self):
        if not self.request.user.is_authenticated:
            return models.ClientPreference.objects.none()
        return models.ClientPreference.objects.filter(
            user=self.request.user
        ).select_related("device")

    def _resolve_device(self, user, device_uuid):
        """Return ClientDevice or None; raise coded 400 if UUID unknown / inactive."""
        if device_uuid is None:
            return None
        try:
            device = models.ClientDevice.objects.get(user=user, uuid=device_uuid)
        except models.ClientDevice.DoesNotExist:
            raise_coded(
                "device_uuid",
                "device_not_registered",
                "Register the device first",
            )
        if not device.is_active:
            raise_coded(
                "device_uuid",
                "device_inactive",
                "Device is inactive; re-register or reactivate",
            )
        return device

    def _scope_filter(self, user, client_id, device):
        scope_filter = Q(user=user, client_id=client_id)
        if device is None:
            scope_filter &= Q(device__isnull=True)
        else:
            scope_filter &= Q(device=device)
        return scope_filter

    def _lock_preference_scope(self, user, client_id, device):
        """
        Serialize concurrent writers on the same preference scope.

        Locks a parent row so empty scopes (nothing to select_for_update on
        ClientPreference) still serialize, then locks existing scope rows.
        """
        if device is not None:
            models.ClientDevice.objects.select_for_update().get(pk=device.pk)
        else:
            # Account-level: lock the user row for first-time concurrent replaces.
            get_user_model().objects.select_for_update().get(pk=user.pk)

        scope_filter = self._scope_filter(user, client_id, device)
        locked = list(
            models.ClientPreference.objects.filter(scope_filter).select_for_update()
        )
        return scope_filter, locked

    def _serialize_rows(self, rows):
        return serializers.ClientPreferenceSerializer(rows, many=True).data

    @extend_schema(
        operation_id="list_client_preferences",
        description=(
            "Return preferences for client_id. With device_uuid, account-level keys "
            "are merged with device overrides (device wins on key name). Without "
            "device_uuid, only account-level (device IS NULL) keys are returned."
        ),
        parameters=[
            OpenApiParameter(
                name="client_id",
                type=str,
                location=OpenApiParameter.QUERY,
                required=True,
                description="Client application id (e.g. tayra).",
            ),
            OpenApiParameter(
                name="device_uuid",
                type=str,
                location=OpenApiParameter.QUERY,
                required=False,
                description=(
                    "Optional device UUID for account∪device overlay resolution."
                ),
            ),
        ],
        responses={200: serializers.ClientPreferenceListResponseSerializer},
    )
    def list(self, request, *args, **kwargs):
        """
        Return preferences for client_id.

        If device_uuid is provided, account-level keys are returned with
        device-specific overrides winning on key name.
        If omitted, only account-level (device IS NULL) keys are returned.

        Inactive (soft-deleted) devices remain readable so historical device
        prefs can be recovered; writes require an active device.
        """
        client_id = request.query_params.get("client_id")
        if not client_id:
            raise_coded(
                "client_id",
                "required",
                "client_id query parameter is required",
            )

        device_uuid_raw = request.query_params.get("device_uuid")
        device = None
        if device_uuid_raw not in (None, ""):
            field = drf_serializers.UUIDField()
            try:
                device_uuid = field.run_validation(device_uuid_raw)
            except drf_serializers.ValidationError:
                raise_coded(
                    "device_uuid",
                    "invalid",
                    "device_uuid must be a valid UUID",
                )
            # GET allows inactive devices so historical prefs remain readable
            try:
                device = models.ClientDevice.objects.get(
                    user=request.user, uuid=device_uuid
                )
            except models.ClientDevice.DoesNotExist:
                raise_coded(
                    "device_uuid",
                    "device_not_registered",
                    "Register the device first",
                )

        qs = self.get_queryset().filter(client_id=client_id)

        if device is None:
            rows = list(qs.filter(device__isnull=True))
        else:
            account_rows = list(qs.filter(device__isnull=True))
            device_rows = list(qs.filter(device=device))
            # Device-specific overrides account-level on same key name
            by_key = {row.key: row for row in account_rows}
            for row in device_rows:
                by_key[row.key] = row
            rows = sorted(by_key.values(), key=lambda r: r.key)

        data = self._serialize_rows(rows)
        return Response({"count": len(data), "results": data})

    @extend_schema(
        operation_id="put_client_preferences",
        description=(
            "Merge or replace preferences for a scope (account or device). "
            "Response results are the written scope only (not the GET overlay). "
            "Sensitive keys are rejected; size limits apply."
        ),
        request=serializers.ClientPreferenceWriteSerializer,
        responses={200: serializers.ClientPreferenceWriteResponseSerializer},
    )
    def update(self, request, *args, **kwargs):
        """
        PUT merge or replace preferences for a scope.

        Response ``results`` are the **written scope only** (not the GET
        device overlay). Effective settings for a device: GET with device_uuid.
        ``resolved`` is always false on PUT.
        """
        write = serializers.ClientPreferenceWriteSerializer(data=request.data)
        write.is_valid(raise_exception=True)
        data = write.validated_data
        client_id = data["client_id"]
        mode = data.get("mode") or "merge"
        preferences = data["preferences"]
        device = self._resolve_device(request.user, data.get("device_uuid"))

        with transaction.atomic():
            scope_filter, locked_rows = self._lock_preference_scope(
                request.user, client_id, device
            )

            if mode == "replace":
                # Locked rows serialize concurrent replaces; delete then insert.
                if locked_rows:
                    models.ClientPreference.objects.filter(
                        pk__in=[r.pk for r in locked_rows]
                    ).delete()
                else:
                    models.ClientPreference.objects.filter(scope_filter).delete()
                # bulk_create skips auto_now; set updated_at explicitly (PostgreSQL NOT NULL)
                now = timezone.now()
                to_create = [
                    models.ClientPreference(
                        user=request.user,
                        client_id=client_id,
                        device=device,
                        key=key,
                        value=value,
                        updated_at=now,
                    )
                    for key, value in preferences.items()
                ]
                if to_create:
                    models.ClientPreference.objects.bulk_create(to_create)
            else:
                # merge: cap check under lock; LWW upsert (never 500 on unique race)
                existing = {row.key: row for row in locked_rows}
                new_keys = set(preferences.keys()) - set(existing.keys())
                if len(existing) + len(new_keys) > MAX_KEYS_PER_SCOPE:
                    raise_coded(
                        "preferences",
                        "too_many_keys",
                        f"At most {MAX_KEYS_PER_SCOPE} keys per scope "
                        f"(would have {len(existing) + len(new_keys)})",
                    )
                for key, value in preferences.items():
                    if key in existing:
                        row = existing[key]
                        row.value = value
                        row.save(update_fields=["value", "updated_at"])
                    else:
                        # update_or_create is idempotent if a race still inserts
                        models.ClientPreference.objects.update_or_create(
                            user=request.user,
                            client_id=client_id,
                            device=device,
                            key=key,
                            defaults={"value": value},
                        )

            rows = list(
                models.ClientPreference.objects.filter(scope_filter)
                .select_related("device")
                .order_by("key")
            )

        data_out = self._serialize_rows(rows)
        return Response(
            {
                "client_id": client_id,
                "device_uuid": str(device.uuid) if device else None,
                "mode": mode,
                # Written scope only — not account∪device overlay (use GET for that).
                "resolved": False,
                "count": len(data_out),
                "results": data_out,
            }
        )


@extend_schema_view(
    list=extend_schema(
        operation_id="list_playback_progress",
        description=(
            "List own playback resume / completed state. "
            "Filter by channel_uuid, completed, updated_at range."
        ),
    ),
    retrieve=extend_schema(
        operation_id="get_playback_progress",
        description="Retrieve playback progress for a track (lookup by track id).",
        responses={200: serializers.PlaybackProgressSerializer},
    ),
    update=extend_schema(
        operation_id="put_playback_progress",
        description=(
            "Upsert progress for a track. Returns 409 progress_conflict when the "
            "client updated_at is older than the server row (LWW)."
        ),
        request=serializers.PlaybackProgressWriteSerializer,
        responses={
            200: serializers.PlaybackProgressSerializer,
            201: serializers.PlaybackProgressSerializer,
            409: serializers.PlaybackProgressConflictSerializer,
        },
    ),
    destroy=extend_schema(
        operation_id="delete_playback_progress",
        description="Clear own progress row for a track.",
        responses={204: None},
    ),
)
class PlaybackProgressViewSet(
    mixins.ListModelMixin,
    mixins.RetrieveModelMixin,
    mixins.DestroyModelMixin,
    viewsets.GenericViewSet,
):
    """Owner-only playback resume / completed state, keyed by track."""

    serializer_class = serializers.PlaybackProgressSerializer
    queryset = models.PlaybackProgress.objects.all().select_related("source_device")
    permission_classes = [
        oauth_permissions.ScopePermission,
        permissions.OwnerPermission,
    ]
    required_scope = "client_data"
    anonymous_policy = False
    owner_checks = ["write"]
    lookup_field = "track_id"
    filterset_class = filters.PlaybackProgressFilter
    http_method_names = ["get", "put", "post", "delete", "head", "options"]

    def get_queryset(self):
        if not self.request.user.is_authenticated:
            return models.PlaybackProgress.objects.none()
        return (
            models.PlaybackProgress.objects.filter(user=self.request.user)
            .select_related("source_device")
            .order_by("-updated_at")
        )

    def _conflict_response(self, instance):
        out = self.get_serializer(instance)
        return Response(
            {
                "code": "progress_conflict",
                "detail": "Client updated_at is older than server",
                "progress": out.data,
            },
            status=status.HTTP_409_CONFLICT,
        )

    def _is_conflict(self, instance, client_updated_at):
        return (
            client_updated_at is not None
            and client_updated_at < instance.updated_at
        )

    def update(self, request, *args, **kwargs):
        """PUT upsert by track_id; 409 if client updated_at is older than server."""
        track_id = self.kwargs[self.lookup_field]
        write = serializers.PlaybackProgressWriteSerializer(data=request.data)
        write.is_valid(raise_exception=True)
        data = write.validated_data

        serializers.ensure_track_exists(track_id)
        client_updated_at = data.get("updated_at")

        try:
            instance = self.get_queryset().get(track_id=track_id)
            created = False
        except models.PlaybackProgress.DoesNotExist:
            instance = models.PlaybackProgress(
                user=request.user, track_id=track_id
            )
            created = True

        if not created and self._is_conflict(instance, client_updated_at):
            return self._conflict_response(instance)

        serializers.apply_progress_fields(instance, data, request.user)
        try:
            with transaction.atomic():
                instance.save()
        except IntegrityError:
            # Concurrent first write for the same (user, track): re-fetch and merge.
            instance = self.get_queryset().get(track_id=track_id)
            created = False
            if self._is_conflict(instance, client_updated_at):
                return self._conflict_response(instance)
            serializers.apply_progress_fields(instance, data, request.user)
            instance.save()

        out = self.get_serializer(instance)
        return Response(
            out.data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )

    def _bulk_row_device_error(self, item, devices_by_uuid):
        """Return (device_or_None, error_dict_or_None) for optional source_device."""
        if "source_device" not in item:
            return None, None
        device_uuid = item["source_device"]
        if device_uuid is None:
            return None, None
        device = devices_by_uuid.get(device_uuid)
        if device is None:
            return None, {
                "code": "device_not_registered",
                "detail": "Register the device via POST /api/v1/client-devices/",
            }
        if not device.is_active:
            return None, {
                "code": "device_inactive",
                "detail": "Device is soft-deleted; re-register or reactivate it",
            }
        return device, None

    def _bulk_apply_and_save(self, instance, item, user, *, is_create):
        """
        Apply fields and save. On IntegrityError for create, re-load and LWW-update.
        Returns ("created"|"updated"|"skipped"|"error", error_dict_or_None).
        """
        client_updated_at = item.get("updated_at") or timezone.now()
        # Ensure LWW timestamp is in the data for apply_progress_fields.
        data = dict(item)
        data["updated_at"] = client_updated_at

        if not is_create and client_updated_at < instance.updated_at:
            return "skipped", None

        try:
            serializers.apply_progress_fields(instance, data, user)
        except ValidationError as exc:
            # Map DRF field errors to a single bulk row code when possible.
            detail = exc.detail
            if isinstance(detail, dict):
                for field, errors in detail.items():
                    if errors and isinstance(errors, list):
                        first = errors[0]
                        if isinstance(first, dict) and "code" in first:
                            return "error", {
                                "code": first["code"],
                                "detail": first.get("detail", str(first)),
                            }
            return "error", {
                "code": "validation_error",
                "detail": "Invalid progress row",
            }

        try:
            with transaction.atomic():
                instance.save()
            return ("created" if is_create else "updated"), None
        except IntegrityError:
            if not is_create:
                logger.exception(
                    "playback progress bulk update IntegrityError user=%s track=%s",
                    user.pk,
                    instance.track_id,
                )
                return "error", {
                    "code": "save_failed",
                    "detail": "Could not save progress row",
                }
            # Race: another writer created the row — re-fetch and LWW-update.
            try:
                existing = models.PlaybackProgress.objects.select_related(
                    "source_device"
                ).get(user=user, track_id=instance.track_id)
            except models.PlaybackProgress.DoesNotExist:
                logger.exception(
                    "playback progress bulk create race without row user=%s track=%s",
                    user.pk,
                    instance.track_id,
                )
                return "error", {
                    "code": "save_failed",
                    "detail": "Could not save progress row",
                }
            if client_updated_at < existing.updated_at:
                return "skipped", None
            try:
                serializers.apply_progress_fields(existing, data, user)
                with transaction.atomic():
                    existing.save()
            except IntegrityError:
                logger.exception(
                    "playback progress bulk LWW-after-race IntegrityError user=%s track=%s",
                    user.pk,
                    instance.track_id,
                )
                return "error", {
                    "code": "save_failed",
                    "detail": "Could not save progress row",
                }
            except ValidationError:
                return "error", {
                    "code": "validation_error",
                    "detail": "Invalid progress row",
                }
            # Update caller's cache via returning updated instance id
            instance.pk = existing.pk
            for field in (
                "position_ms",
                "duration_ms",
                "completed",
                "channel_uuid",
                "updated_at",
                "source_device_id",
            ):
                setattr(instance, field, getattr(existing, field))
            return "updated", None

    @extend_schema(
        operation_id="bulk_playback_progress",
        description=(
            "Migration import of progress rows. Last-write-wins by updated_at; "
            "partial success with per-row errors. Max 500 items."
        ),
        request=serializers.PlaybackProgressBulkSerializer,
        responses={200: serializers.PlaybackProgressBulkResultSerializer},
    )
    @action(methods=["post"], detail=False, url_path="bulk")
    def bulk(self, request, *args, **kwargs):
        """Migration import: last-write-wins by updated_at; partial success."""
        ser = serializers.PlaybackProgressBulkSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        items = ser.validated_data["items"]
        user = request.user

        track_ids = {item["track"] for item in items}
        existing_tracks = set(
            Track.objects.filter(pk__in=track_ids).values_list("pk", flat=True)
        )
        existing_progress = {
            p.track_id: p
            for p in models.PlaybackProgress.objects.filter(
                user=user, track_id__in=track_ids
            ).select_related("source_device")
        }

        device_uuids = {
            item["source_device"]
            for item in items
            if item.get("source_device") is not None
        }
        devices_by_uuid = {
            d.uuid: d
            for d in models.ClientDevice.objects.filter(
                user=user, uuid__in=device_uuids
            )
        }

        created = 0
        updated = 0
        skipped = 0
        errors = []

        for index, item in enumerate(items):
            track_id = item["track"]
            if track_id not in existing_tracks:
                errors.append(
                    {
                        "index": index,
                        "code": "track_not_found",
                        "detail": f"Track {track_id} does not exist",
                    }
                )
                continue

            # Validate device early when provided (same codes as PUT).
            if "source_device" in item and item["source_device"] is not None:
                _device, device_err = self._bulk_row_device_error(
                    item, devices_by_uuid
                )
                if device_err is not None:
                    errors.append({"index": index, **device_err})
                    continue

            existing = existing_progress.get(track_id)
            if existing is not None:
                result, err = self._bulk_apply_and_save(
                    existing, item, user, is_create=False
                )
            else:
                progress = models.PlaybackProgress(
                    user=user, track_id=track_id
                )
                result, err = self._bulk_apply_and_save(
                    progress, item, user, is_create=True
                )
                if result in ("created", "updated"):
                    # Refresh cache: re-fetch so subsequent items for same track merge.
                    try:
                        existing_progress[track_id] = (
                            models.PlaybackProgress.objects.select_related(
                                "source_device"
                            ).get(user=user, track_id=track_id)
                        )
                    except models.PlaybackProgress.DoesNotExist:
                        pass

            if result == "created":
                created += 1
            elif result == "updated":
                updated += 1
                if track_id in existing_progress:
                    # Keep cache in sync after update
                    try:
                        existing_progress[track_id] = (
                            models.PlaybackProgress.objects.select_related(
                                "source_device"
                            ).get(user=user, track_id=track_id)
                        )
                    except models.PlaybackProgress.DoesNotExist:
                        pass
            elif result == "skipped":
                skipped += 1
            else:
                errors.append({"index": index, **(err or {"code": "save_failed", "detail": "Could not save progress row"})})

        return Response(
            {
                "created": created,
                "updated": updated,
                "skipped": skipped,
                "errors": errors,
            },
            status=status.HTTP_200_OK,
        )
