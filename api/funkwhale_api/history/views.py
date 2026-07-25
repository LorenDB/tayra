from django.db.models import Prefetch
from rest_framework import mixins, status, viewsets
from rest_framework.response import Response

from config import plugins
from funkwhale_api.activity import record
from funkwhale_api.common import fields, permissions
from funkwhale_api.music import utils as music_utils
from funkwhale_api.music.models import Track
from funkwhale_api.users.oauth import permissions as oauth_permissions

from . import filters, models, serializers


class ListeningViewSet(
    mixins.CreateModelMixin,
    mixins.ListModelMixin,
    mixins.RetrieveModelMixin,
    viewsets.GenericViewSet,
):
    serializer_class = serializers.ListeningSerializer
    queryset = models.Listening.objects.all().select_related(
        "user__actor__attachment_icon",
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

    def get_serializer_class(self):
        if self.request.method.lower() in ["head", "get", "options"]:
            return serializers.ListeningSerializer
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

    def get_queryset(self):
        queryset = super().get_queryset()
        queryset = queryset.filter(
            fields.privacy_level_query(self.request.user, "user__privacy_level")
        )
        tracks = Track.objects.with_playable_uploads(
            music_utils.get_actor_from_request(self.request)
        ).select_related(
            "artist", "album__artist", "attributed_to", "artist__attachment_cover"
        )
        return queryset.prefetch_related(Prefetch("track", queryset=tracks))

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context["user"] = self.request.user
        return context
