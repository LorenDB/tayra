import json
import logging
from cache_memoize import cache_memoize

from django.conf import settings
from django.urls import reverse

from dynamic_preferences.api.serializers import GlobalPreferenceSerializer
from dynamic_preferences.api import viewsets as preferences_viewsets
from dynamic_preferences.registries import global_preferences_registry
from rest_framework import generics
from rest_framework import views
from rest_framework.response import Response

from funkwhale_api import __version__ as funkwhale_version
from funkwhale_api.common import middleware
from funkwhale_api.common import preferences
from funkwhale_api.common.renderers import ActivityStreamRenderer
from funkwhale_api.federation.models import Domain
from funkwhale_api.federation.actors import get_service_actor
from funkwhale_api.users.oauth import permissions as oauth_permissions
from funkwhale_api.music.utils import SUPPORTED_EXTENSIONS
from funkwhale_api.moderation.models import REPORT_TYPES

from drf_spectacular.utils import extend_schema

from . import serializers
from . import stats

NODEINFO_2_CONTENT_TYPE = "application/json; profile=http://nodeinfo.diaspora.software/ns/schema/2.0#; charset=utf-8"  # noqa


logger = logging.getLogger(__name__)


class AdminSettings(preferences_viewsets.GlobalPreferencesViewSet):
    pagination_class = None
    permission_classes = [oauth_permissions.ScopePermission]
    required_scope = "instance:settings"


class InstanceSettings(generics.GenericAPIView):
    permission_classes = []
    authentication_classes = []
    serializer_class = GlobalPreferenceSerializer

    def get_queryset(self):
        manager = global_preferences_registry.manager()
        manager.all()
        all_preferences = manager.model.objects.all().order_by("section", "name")
        api_preferences = [
            p for p in all_preferences if getattr(p.preference, "show_in_api", False)
        ]
        return api_preferences

    @extend_schema(operation_id="get_instance_settings")
    def get(self, request):
        queryset = self.get_queryset()
        data = GlobalPreferenceSerializer(queryset, many=True).data
        return Response(data, status=200)


class NodeInfo(views.APIView):
    permission_classes = []
    authentication_classes = []

    @extend_schema(
        responses=serializers.NodeInfo20Serializer, operation_id="getNodeInfo20"
    )
    def get(self, request):
        pref = preferences.all()
        if (
            pref["moderation__allow_list_public"]
            and pref["moderation__allow_list_enabled"]
        ):
            allowed_domains = list(
                Domain.objects.filter(allowed=True)
                .order_by("name")
                .values_list("name", flat=True)
            )
        else:
            allowed_domains = None

        data = {
            "software": {"version": funkwhale_version},
            "preferences": pref,
            "stats": cache_memoize(600, prefix="memoize:instance:stats")(stats.get)()
            if pref["instance__nodeinfo_stats_enabled"]
            else None,
            "actorId": get_service_actor().fid,
            "supportedUploadExtensions": SUPPORTED_EXTENSIONS,
            "allowed_domains": allowed_domains,
            "report_types": [
                {
                    "type": t,
                    "label": l,
                    "anonymous": t
                    in pref.get("moderation__unauthenticated_report_types"),
                }
                for t, l in REPORT_TYPES
            ],
            "endpoints": {},
        }

        if not pref.get("common__api_authentication_required"):
            if pref.get("instance__nodeinfo_stats_enabled"):
                data["endpoints"]["knownNodes"] = reverse(
                    "api:v1:federation:domains-list"
                )
            if pref.get("federation__public_index"):
                data["endpoints"]["libraries"] = reverse(
                    "federation:index:index-libraries"
                )
                data["endpoints"]["channels"] = reverse(
                    "federation:index:index-channels"
                )
        serializer = serializers.NodeInfo20Serializer(data)
        return Response(
            serializer.data, status=200, content_type=NODEINFO_2_CONTENT_TYPE
        )


class SpaManifest(generics.GenericAPIView):
    permission_classes = []
    authentication_classes = []
    serializer_class = serializers.SpaManifestSerializer
    renderer_classes = [ActivityStreamRenderer]

    @extend_schema(operation_id="get_spa_manifest")
    def get(self, request):
        existing_manifest = middleware.get_spa_file(
            settings.FUNKWHALE_SPA_HTML_ROOT, "manifest.json"
        )
        parsed_manifest = json.loads(existing_manifest)
        instance_name = preferences.get("instance__name")
        if instance_name:
            parsed_manifest["short_name"] = instance_name
            parsed_manifest["name"] = instance_name
        instance_description = preferences.get("instance__short_description")
        if instance_description:
            parsed_manifest["description"] = instance_description
        serializer = self.get_serializer(parsed_manifest)
        return Response(
            serializer.data, status=200, content_type="application/manifest+json"
        )
