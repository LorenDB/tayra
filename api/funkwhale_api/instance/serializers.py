from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from funkwhale_api.federation.utils import full_url


class SoftwareSerializer(serializers.Serializer):
    name = serializers.SerializerMethodField()
    version = serializers.CharField()

    def get_name(self, obj) -> str:
        return "funkwhale"


class SoftwareSerializer_v2(SoftwareSerializer):
    repository = serializers.SerializerMethodField()
    homepage = serializers.SerializerMethodField()

    def get_repository(self, obj):
        return "https://dev.funkwhale.audio/funkwhale/funkwhale"

    def get_homepage(self, obj):
        return "https://funkwhale.audio"


class ServicesSerializer(serializers.Serializer):
    inbound = serializers.ListField(child=serializers.CharField(), default=[])
    outbound = serializers.ListField(child=serializers.CharField(), default=[])


class UsersUsageSerializer(serializers.Serializer):
    total = serializers.IntegerField()
    activeHalfyear = serializers.SerializerMethodField()
    activeMonth = serializers.SerializerMethodField()

    def get_activeHalfyear(self, obj) -> int:
        return obj.get("active_halfyear", 0)

    def get_activeMonth(self, obj) -> int:
        return obj.get("active_month", 0)


class UsageSerializer(serializers.Serializer):
    users = UsersUsageSerializer()
    localPosts = serializers.IntegerField(required=False)
    localComments = serializers.IntegerField(required=False)


class TotalCountSerializer(serializers.Serializer):
    total = serializers.SerializerMethodField()

    def get_total(self, obj) -> int:
        return obj


class TotalHoursSerializer(serializers.Serializer):
    hours = serializers.SerializerMethodField()

    def get_hours(self, obj) -> int:
        return obj


class NodeInfoLibrarySerializer(serializers.Serializer):
    federationEnabled = serializers.BooleanField()
    anonymousCanListen = serializers.BooleanField()
    tracks = TotalCountSerializer(default=0)
    artists = TotalCountSerializer(default=0)
    albums = TotalCountSerializer(default=0)
    music = TotalHoursSerializer(source="music_duration", default=0)


class AllowListStatSerializer(serializers.Serializer):
    enabled = serializers.BooleanField()
    domains = serializers.ListField(child=serializers.CharField())


class ReportTypeSerializer(serializers.Serializer):
    type = serializers.CharField()
    label = serializers.CharField()
    anonymous = serializers.BooleanField()


class EndpointsSerializer(serializers.Serializer):
    knownNodes = serializers.URLField(default=None)
    channels = serializers.URLField(default=None)
    libraries = serializers.URLField(default=None)


class MetadataUsageFavoriteSerializer(serializers.Serializer):
    tracks = serializers.SerializerMethodField()

    @extend_schema_field(TotalCountSerializer)
    def get_tracks(self, obj):
        return TotalCountSerializer(obj).data


class MetadataUsageSerializer(serializers.Serializer):
    favorites = MetadataUsageFavoriteSerializer(source="track_favorites")
    listenings = TotalCountSerializer()
    downloads = TotalCountSerializer()


class MetadataSerializer(serializers.Serializer):
    actorId = serializers.CharField()
    private = serializers.SerializerMethodField()
    shortDescription = serializers.SerializerMethodField()
    longDescription = serializers.SerializerMethodField()
    contactEmail = serializers.SerializerMethodField()
    nodeName = serializers.SerializerMethodField()
    banner = serializers.SerializerMethodField()
    defaultUploadQuota = serializers.SerializerMethodField()
    supportedUploadExtensions = serializers.ListField(child=serializers.CharField())
    allowList = serializers.SerializerMethodField()
    funkwhaleSupportMessageEnabled = serializers.SerializerMethodField()
    instanceSupportMessage = serializers.SerializerMethodField()
    usage = MetadataUsageSerializer(source="stats", required=False)

    def get_private(self, obj) -> bool:
        return obj["preferences"].get("instance__nodeinfo_private")

    def get_shortDescription(self, obj) -> str:
        return obj["preferences"].get("instance__short_description")

    def get_longDescription(self, obj) -> str:
        return obj["preferences"].get("instance__long_description")

    def get_contactEmail(self, obj) -> str:
        return obj["preferences"].get("instance__contact_email")

    def get_nodeName(self, obj) -> str:
        return obj["preferences"].get("instance__name")

    @extend_schema_field(serializers.CharField)
    def get_banner(self, obj) -> (str, None):
        if obj["preferences"].get("instance__banner"):
            return full_url(obj["preferences"].get("instance__banner").url)
        return None

    def get_defaultUploadQuota(self, obj) -> int:
        return obj["preferences"].get("users__upload_quota")

    @extend_schema_field(AllowListStatSerializer)
    def get_allowList(self, obj):
        return AllowListStatSerializer(
            {
                "enabled": obj["preferences"].get("moderation__allow_list_enabled"),
                "domains": obj["allowed_domains"] or None,
            }
        ).data

    def get_funkwhaleSupportMessageEnabled(self, obj) -> bool:
        return obj["preferences"].get("instance__funkwhale_support_message_enabled")

    def get_instanceSupportMessage(self, obj) -> str:
        return obj["preferences"].get("instance__support_message")

    @extend_schema_field(MetadataUsageSerializer)
    def get_usage(self, obj):
        return MetadataUsageSerializer(obj["stats"]).data


class Metadata20Serializer(MetadataSerializer):
    library = serializers.SerializerMethodField()
    reportTypes = ReportTypeSerializer(source="report_types", many=True)
    endpoints = EndpointsSerializer()
    rules = serializers.SerializerMethodField()
    terms = serializers.SerializerMethodField()

    def get_rules(self, obj) -> str:
        return obj["preferences"].get("instance__rules")

    def get_terms(self, obj) -> str:
        return obj["preferences"].get("instance__terms")

    @extend_schema_field(NodeInfoLibrarySerializer)
    def get_library(self, obj):
        data = obj["stats"] or {}
        data["federationEnabled"] = obj["preferences"].get("federation__enabled")
        data["anonymousCanListen"] = not obj["preferences"].get(
            "common__api_authentication_required"
        )
        return NodeInfoLibrarySerializer(data).data


class MetadataContentLocalSerializer(serializers.Serializer):
    artists = serializers.IntegerField()
    releases = serializers.IntegerField()
    recordings = serializers.IntegerField()
    hoursOfContent = serializers.IntegerField()


class MetadataContentCategorySerializer(serializers.Serializer):
    name = serializers.CharField()
    count = serializers.IntegerField()


class MetadataContentSerializer(serializers.Serializer):
    local = MetadataContentLocalSerializer()
    topMusicCategories = MetadataContentCategorySerializer(many=True)
    topPodcastCategories = MetadataContentCategorySerializer(many=True)


class Metadata21Serializer(MetadataSerializer):
    languages = serializers.ListField(child=serializers.CharField())
    location = serializers.CharField()
    content = MetadataContentSerializer()
    features = serializers.ListField(child=serializers.CharField())
    codeOfConduct = serializers.SerializerMethodField()

    def get_codeOfConduct(self, obj) -> str:
        return (
            full_url("/about/pod#rules")
            if obj["preferences"].get("instance__rules")
            else ""
        )


class NodeInfo20Serializer(serializers.Serializer):
    version = serializers.SerializerMethodField()
    software = SoftwareSerializer()
    protocols = serializers.SerializerMethodField()
    services = ServicesSerializer(default={})
    openRegistrations = serializers.SerializerMethodField()
    usage = serializers.SerializerMethodField()
    metadata = serializers.SerializerMethodField()

    def get_version(self, obj) -> str:
        return "2.0"

    def get_protocols(self, obj) -> list:
        return ["activitypub"]

    def get_services(self, obj) -> object:
        return {"inbound": [], "outbound": []}

    def get_openRegistrations(self, obj) -> bool:
        return obj["preferences"]["users__registration_enabled"]

    @extend_schema_field(UsageSerializer)
    def get_usage(self, obj):
        usage = None
        if obj["preferences"]["instance__nodeinfo_stats_enabled"]:
            usage = obj["stats"]
        else:
            usage = {"users": {"total": 0, "activeMonth": 0, "activeHalfyear": 0}}
        return UsageSerializer(usage).data

    @extend_schema_field(Metadata20Serializer)
    def get_metadata(self, obj):
        return Metadata20Serializer(obj).data


class NodeInfo21Serializer(NodeInfo20Serializer):
    version = serializers.SerializerMethodField()
    software = SoftwareSerializer_v2()

    def get_version(self, obj) -> str:
        return "2.1"

    @extend_schema_field(UsageSerializer)
    def get_usage(self, obj):
        usage = None
        if obj["preferences"]["instance__nodeinfo_stats_enabled"]:
            usage = obj["stats"]
            usage["localPosts"] = 0
            usage["localComments"] = 0
        else:
            usage = {
                "users": {"total": 0, "activeMonth": 0, "activeHalfyear": 0},
                "localPosts": 0,
                "localComments": 0,
            }
        return UsageSerializer(usage).data

    @extend_schema_field(Metadata21Serializer)
    def get_metadata(self, obj):
        return Metadata21Serializer(obj).data


class SpaManifestIconSerializer(serializers.Serializer):
    src = serializers.CharField()
    sizes = serializers.CharField()
    type = serializers.CharField()


class SpaManifestRelatedApplicationsSerializer(serializers.Serializer):
    platform = serializers.CharField()
    url = serializers.URLField()
    id = serializers.CharField()


class SpaManifestShortcutSerializer(serializers.Serializer):
    name = serializers.CharField()
    url = serializers.CharField()
    icons = SpaManifestIconSerializer(many=True, required=False)


class SpaManifestSerializer(serializers.Serializer):
    name = serializers.CharField(default="Funkwhale")
    short_name = serializers.CharField(default="Funkwhale")
    display = serializers.CharField(required=False)
    background_color = serializers.CharField(required=False)
    lang = serializers.CharField(required=False)
    categories = serializers.ListField(child=serializers.CharField(), required=False)
    description = serializers.CharField(required=False)
    icons = SpaManifestIconSerializer(many=True, required=False)
    start_url = serializers.CharField(required=False)
    prefer_related_applications = serializers.BooleanField(required=False)
    related_applications = SpaManifestRelatedApplicationsSerializer(
        many=True, required=False
    )
    shortcuts = SpaManifestShortcutSerializer(many=True, required=False)
