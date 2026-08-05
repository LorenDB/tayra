from django.http import Http404
from drf_spectacular.utils import extend_schema
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from funkwhale_api.common import permissions as common_permissions
from funkwhale_api.users.oauth import permissions as oauth_permissions

from . import models, permissions as share_permissions, serializers


class ShareLinkViewSet(
    mixins.CreateModelMixin,
    mixins.ListModelMixin,
    mixins.RetrieveModelMixin,
    mixins.DestroyModelMixin,
    viewsets.GenericViewSet,
):
    """
    Owner CRUD for secret share links, plus a public resolve action.

    Public resolve is intentionally unauthenticated: possession of the token
    is the only credential. Stream authorization uses ``?share=`` on listen.
    """

    serializer_class = serializers.ShareLinkSerializer
    queryset = models.ShareLink.objects.all()
    lookup_field = "uuid"
    permission_classes = [
        oauth_permissions.ScopePermission,
        common_permissions.OwnerPermission,
    ]
    required_scope = "libraries"
    # Public action opts out via decorator; owner endpoints require auth.
    anonymous_policy = False
    owner_field = "owner"
    owner_checks = ["read", "write"]
    throttling_scopes = {
        "create": {
            "authenticated": "authenticated-create",
            "anonymous": "anonymous-create",
        },
        "public": {
            "authenticated": "share-public",
            "anonymous": "share-public",
        },
    }

    def get_queryset(self):
        qs = super().get_queryset()
        user = self.request.user
        if not user.is_authenticated:
            return qs.none()
        qs = qs.filter(owner=user)
        object_type = self.request.query_params.get("object_type")
        object_id = self.request.query_params.get("object_id")
        if object_type:
            qs = qs.filter(object_type=object_type)
        if object_id:
            try:
                qs = qs.filter(object_id=int(object_id))
            except (TypeError, ValueError):
                qs = qs.none()
        return qs

    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)

    @extend_schema(
        responses=serializers.PublicShareSerializer,
        operation_id="resolve_public_share",
        summary="Resolve a secret share link",
        description=(
            "Returns metadata and tracks for the shared album or playlist. "
            "No authentication; the URL token is the credential. "
            "Invalid, revoked, or expired tokens return 404."
        ),
    )
    @action(
        methods=["get"],
        detail=False,
        url_path=r"public/(?P<token>[^/.]+)",
        url_name="public",
        authentication_classes=[],
        permission_classes=[],
        serializer_class=serializers.PublicShareSerializer,
    )
    def public(self, request, token=None, *args, **kwargs):
        # Same resolution path as stream auth (active, owner active, length bound).
        link = share_permissions.resolve_active_share(token or "")
        if link is None:
            raise Http404
        if link.get_object() is None:
            raise Http404
        data = serializers.PublicShareSerializer(
            link, context={"request": request}
        ).data
        return Response(data, status=status.HTTP_200_OK)
