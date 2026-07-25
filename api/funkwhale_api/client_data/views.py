from django.contrib.auth import get_user_model
from django.db import transaction
from django.db.models import Q
from django.utils import timezone
from rest_framework import mixins, serializers as drf_serializers, status, viewsets
from rest_framework.response import Response

from funkwhale_api.common import permissions
from funkwhale_api.users.oauth import permissions as oauth_permissions

from . import models, serializers
from .serializers import MAX_KEYS_PER_SCOPE, raise_coded


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
