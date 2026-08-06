from django.db import transaction
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from funkwhale_api.audio import models as audio_models
from funkwhale_api.common import serializers as common_serializers
from funkwhale_api.music import models as music_models
from funkwhale_api.music import serializers as music_serializers
from funkwhale_api.tags import models as tags_models
from funkwhale_api.users import models as users_models

from . import filters


class PermissionsSerializer(serializers.Serializer):
    def to_representation(self, o):
        return o.get_permissions(defaults=self.context.get("default_permissions"))

    def to_internal_value(self, o):
        return {"permissions": o}


class ManageUserSimpleSerializer(serializers.ModelSerializer):
    class Meta:
        model = users_models.User
        fields = (
            "id",
            "username",
            "email",
            "name",
            "is_active",
            "is_staff",
            "is_superuser",
            "date_joined",
            "last_activity",
            "privacy_level",
            "upload_quota",
        )


class ManageUserSerializer(serializers.ModelSerializer):
    permissions = PermissionsSerializer(source="*")
    upload_quota = serializers.IntegerField(allow_null=True, required=False)

    class Meta:
        model = users_models.User
        fields = (
            "id",
            "username",
            "email",
            "name",
            "is_active",
            "is_staff",
            "is_superuser",
            "date_joined",
            "last_activity",
            "permissions",
            "privacy_level",
            "upload_quota",
            "full_username",
        )
        read_only_fields = [
            "id",
            "email",
            "privacy_level",
            "username",
            "date_joined",
            "last_activity",
        ]

    def update(self, instance, validated_data):
        instance = super().update(instance, validated_data)
        permissions = validated_data.pop("permissions", {})
        if permissions:
            for p, value in permissions.items():
                setattr(instance, f"permission_{p}", value)
            instance.save(update_fields=[f"permission_{p}" for p in permissions.keys()])
        return instance


class ManageInvitationSerializer(serializers.ModelSerializer):
    users = ManageUserSimpleSerializer(many=True, required=False)
    owner = ManageUserSimpleSerializer(required=False)
    invited_user = ManageUserSimpleSerializer(required=False)
    code = serializers.CharField(required=False, allow_null=True)

    class Meta:
        model = users_models.Invitation
        fields = (
            "id",
            "owner",
            "invited_user",
            "code",
            "expiration_date",
            "creation_date",
            "users",
        )
        read_only_fields = [
            "id",
            "expiration_date",
            "owner",
            "invited_user",
            "creation_date",
            "users",
        ]

    def validate_code(self, value):
        if not value:
            return value
        if users_models.Invitation.objects.filter(code__iexact=value).exists():
            raise serializers.ValidationError(
                "An invitation with this code already exists"
            )
        return value


class ManageInvitationActionSerializer(common_serializers.ActionSerializer):
    actions = [
        common_serializers.Action(
            "delete", allow_all=False, qs_filter=lambda qs: qs.open()
        )
    ]
    filterset_class = filters.ManageInvitationFilterSet

    @transaction.atomic
    def handle_delete(self, objects):
        return objects.delete()


class ManageBaseArtistSerializer(serializers.ModelSerializer):
    class Meta:
        model = music_models.Artist
        fields = ["id", "mbid", "name", "creation_date", "is_local"]


class ManageBaseAlbumSerializer(serializers.ModelSerializer):
    cover = music_serializers.cover_field
    tracks_count = serializers.SerializerMethodField()

    class Meta:
        model = music_models.Album
        fields = [
            "id",
            "mbid",
            "title",
            "creation_date",
            "release_date",
            "cover",
            "is_local",
            "tracks_count",
        ]

    @extend_schema_field(OpenApiTypes.INT)
    def get_tracks_count(self, o):
        return getattr(o, "_tracks_count", None)


class ManageNestedTrackSerializer(serializers.ModelSerializer):
    class Meta:
        model = music_models.Track
        fields = [
            "id",
            "mbid",
            "title",
            "creation_date",
            "position",
            "disc_number",
            "is_local",
            "copyright",
            "license",
        ]


class ManageNestedAlbumSerializer(ManageBaseAlbumSerializer):
    tracks_count = serializers.SerializerMethodField()

    class Meta:
        model = music_models.Album
        fields = ManageBaseAlbumSerializer.Meta.fields + ["tracks_count"]

    @extend_schema_field(OpenApiTypes.INT)
    def get_tracks_count(self, obj):
        return getattr(obj, "tracks_count", None)


class ManageArtistSerializer(
    music_serializers.OptionalDescriptionMixin, ManageBaseArtistSerializer
):
    tags = serializers.SerializerMethodField()
    tracks_count = serializers.SerializerMethodField()
    albums_count = serializers.SerializerMethodField()
    channel = serializers.SerializerMethodField()
    cover = music_serializers.CoverField(allow_null=True)

    class Meta:
        model = music_models.Artist
        fields = ManageBaseArtistSerializer.Meta.fields + [
            "tracks_count",
            "albums_count",
            "tags",
            "cover",
            "channel",
            "content_category",
        ]

    @extend_schema_field(OpenApiTypes.INT)
    def get_tracks_count(self, obj):
        return getattr(obj, "_tracks_count", None)

    @extend_schema_field(OpenApiTypes.INT)
    def get_albums_count(self, obj):
        return getattr(obj, "_albums_count", None)

    @extend_schema_field({"type": "array", "items": {"type": "string"}})
    def get_tags(self, obj):
        tagged_items = getattr(obj, "_prefetched_tagged_items", [])
        return [ti.tag.name for ti in tagged_items]

    @extend_schema_field(OpenApiTypes.STR)
    def get_channel(self, obj):
        if "channel" in obj._state.fields_cache and obj.get_channel():
            return str(obj.channel.uuid)


class ManageNestedArtistSerializer(ManageBaseArtistSerializer):
    pass


class ManageNestedArtistCreditSerializer(serializers.ModelSerializer):
    artist = ManageNestedArtistSerializer()

    class Meta:
        model = music_models.ArtistCredit
        fields = ["artist", "credit", "joinphrase", "index"]


class ManageAlbumSerializer(
    music_serializers.OptionalDescriptionMixin, ManageBaseAlbumSerializer
):
    artist_credit = ManageNestedArtistCreditSerializer(many=True)
    tags = serializers.SerializerMethodField()

    class Meta:
        model = music_models.Album
        fields = ManageBaseAlbumSerializer.Meta.fields + [
            "artist_credit",
            "tags",
            "tracks_count",
        ]

    def get_tracks_count(self, o) -> int:
        return len(o.tracks.all())

    @extend_schema_field({"type": "array", "items": {"type": "string"}})
    def get_tags(self, obj):
        tagged_items = getattr(obj, "_prefetched_tagged_items", [])
        return [ti.tag.name for ti in tagged_items]


class ManageTrackAlbumSerializer(ManageBaseAlbumSerializer):
    artist_credit = ManageNestedArtistCreditSerializer(many=True)

    class Meta:
        model = music_models.Album
        fields = ManageBaseAlbumSerializer.Meta.fields + ["artist_credit"]


class ManageTrackSerializer(
    music_serializers.OptionalDescriptionMixin, ManageNestedTrackSerializer
):
    artist_credit = ManageNestedArtistCreditSerializer(many=True)
    album = ManageTrackAlbumSerializer(allow_null=True)
    uploads_count = serializers.SerializerMethodField()
    tags = serializers.SerializerMethodField()
    cover = music_serializers.cover_field

    class Meta:
        model = music_models.Track
        fields = ManageNestedTrackSerializer.Meta.fields + [
            "artist_credit",
            "album",
            "uploads_count",
            "tags",
            "cover",
        ]

    @extend_schema_field(OpenApiTypes.INT)
    def get_uploads_count(self, obj):
        return getattr(obj, "uploads_count", None)

    @extend_schema_field({"type": "array", "items": {"type": "string"}})
    def get_tags(self, obj):
        tagged_items = getattr(obj, "_prefetched_tagged_items", [])
        return [ti.tag.name for ti in tagged_items]


class ManageTrackActionSerializer(common_serializers.ActionSerializer):
    actions = [common_serializers.Action("delete", allow_all=False)]
    filterset_class = filters.ManageTrackFilterSet

    @transaction.atomic
    def handle_delete(self, objects):
        return objects.delete()


class ManageAlbumActionSerializer(common_serializers.ActionSerializer):
    actions = [common_serializers.Action("delete", allow_all=False)]
    filterset_class = filters.ManageAlbumFilterSet

    @transaction.atomic
    def handle_delete(self, objects):
        return objects.delete()


class ManageArtistActionSerializer(common_serializers.ActionSerializer):
    actions = [common_serializers.Action("delete", allow_all=False)]
    filterset_class = filters.ManageArtistFilterSet

    @transaction.atomic
    def handle_delete(self, objects):
        return objects.delete()


class ManageLibraryActionSerializer(common_serializers.ActionSerializer):
    actions = [common_serializers.Action("delete", allow_all=False)]
    filterset_class = filters.ManageLibraryFilterSet

    @transaction.atomic
    def handle_delete(self, objects):
        return objects.delete()


class ManageUploadActionSerializer(common_serializers.ActionSerializer):
    actions = [common_serializers.Action("delete", allow_all=False)]
    filterset_class = filters.ManageUploadFilterSet

    @transaction.atomic
    def handle_delete(self, objects):
        return objects.delete()


class ManageLibrarySerializer(serializers.ModelSerializer):
    domain = serializers.CharField(default="")
    uploads_count = serializers.SerializerMethodField()
    followers_count = serializers.SerializerMethodField()

    class Meta:
        model = music_models.Library
        fields = [
            "id",
            "uuid",
            "name",
            "description",
            "domain",
            "is_local",
            "creation_date",
            "privacy_level",
            "uploads_count",
            "followers_count",
        ]
        read_only_fields = [
            "uuid",
            "id",
            "domain",
            "is_local",
            "creation_date",
        ]

    def get_uploads_count(self, obj) -> int:
        return getattr(obj, "_uploads_count", int(obj.uploads_count))

    @extend_schema_field(OpenApiTypes.INT)
    def get_followers_count(self, obj):
        return 0


class ManageNestedLibrarySerializer(serializers.ModelSerializer):
    domain = serializers.CharField(default="")

    class Meta:
        model = music_models.Library
        fields = [
            "id",
            "uuid",
            "name",
            "description",
            "domain",
            "is_local",
            "creation_date",
            "privacy_level",
        ]


class ManageUploadSerializer(serializers.ModelSerializer):
    track = ManageNestedTrackSerializer()
    library = ManageNestedLibrarySerializer()
    domain = serializers.CharField(default="")

    class Meta:
        model = music_models.Upload
        fields = (
            "id",
            "uuid",
            "domain",
            "is_local",
            "audio_file",
            "listen_url",
            "source",
            "filename",
            "mimetype",
            "duration",
            "mimetype",
            "bitrate",
            "size",
            "creation_date",
            "accessed_date",
            "modification_date",
            "metadata",
            "import_date",
            "import_details",
            "import_status",
            "import_metadata",
            "import_reference",
            "track",
            "library",
        )


class ManageTagSerializer(ManageBaseAlbumSerializer):
    tracks_count = serializers.SerializerMethodField()
    albums_count = serializers.SerializerMethodField()
    artists_count = serializers.SerializerMethodField()

    class Meta:
        model = tags_models.Tag
        fields = [
            "id",
            "name",
            "creation_date",
            "tracks_count",
            "albums_count",
            "artists_count",
        ]

    @extend_schema_field(OpenApiTypes.INT)
    def get_tracks_count(self, obj):
        return getattr(obj, "_tracks_count", None)

    @extend_schema_field(OpenApiTypes.INT)
    def get_albums_count(self, obj):
        return getattr(obj, "_albums_count", None)

    @extend_schema_field(OpenApiTypes.INT)
    def get_artists_count(self, obj):
        return getattr(obj, "_artists_count", None)


class ManageTagActionSerializer(common_serializers.ActionSerializer):
    actions = [common_serializers.Action("delete", allow_all=False)]
    filterset_class = filters.ManageTagFilterSet
    pk_field = "name"

    @transaction.atomic
    def handle_delete(self, objects):
        return objects.delete()


class ManageChannelSerializer(serializers.ModelSerializer):
    artist = ManageArtistSerializer()

    class Meta:
        model = audio_models.Channel
        fields = [
            "id",
            "uuid",
            "creation_date",
            "artist",
            "rss_url",
            "metadata",
        ]
        read_only_fields = fields
