from django.utils import timezone
from rest_framework import mixins, status, viewsets
from rest_framework.response import Response

from funkwhale_api.common import permissions
from funkwhale_api.users.oauth import permissions as oauth_permissions

from . import models, serializers


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
