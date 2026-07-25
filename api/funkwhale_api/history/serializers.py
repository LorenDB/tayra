import datetime

from django.db import IntegrityError, transaction
from django.utils import timezone
from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from funkwhale_api.activity import serializers as activity_serializers
from funkwhale_api.client_data.models import ClientDevice
from funkwhale_api.common.serializers import raise_coded_validation_error
from funkwhale_api.federation import serializers as federation_serializers
from funkwhale_api.music.serializers import TrackActivitySerializer, TrackSerializer
from funkwhale_api.users.serializers import UserActivitySerializer, UserBasicSerializer

from . import bulk as bulk_module
from . import models

_CREATION_DATE_WINDOW = datetime.timedelta(minutes=5)


def resolve_source_device(user, device_uuid):
    """Resolve an active ClientDevice UUID for the given user, or raise coded 400."""
    try:
        device = ClientDevice.objects.get(user=user, uuid=device_uuid)
    except ClientDevice.DoesNotExist:
        raise_coded_validation_error(
            "source_device",
            "device_not_registered",
            "Register the device via POST /api/v1/client-devices/",
        )
    if not device.is_active:
        raise_coded_validation_error(
            "source_device",
            "device_inactive",
            "Device is inactive; re-register via POST /api/v1/client-devices/",
        )
    return device


class ListeningActivitySerializer(activity_serializers.ModelSerializer):
    type = serializers.SerializerMethodField()
    object = TrackActivitySerializer(source="track")
    actor = UserActivitySerializer(source="user")
    published = serializers.DateTimeField(source="creation_date")

    class Meta:
        model = models.Listening
        fields = ["id", "local_id", "object", "type", "actor", "published"]

    def get_actor(self, obj):
        return UserActivitySerializer(obj.user).data

    def get_type(self, obj):
        return "Listen"


class ListeningSerializer(serializers.ModelSerializer):
    track = TrackSerializer(read_only=True)
    user = UserBasicSerializer(read_only=True)
    actor = serializers.SerializerMethodField()
    source_device = serializers.SerializerMethodField()

    RICH_FIELDS = (
        "duration_seconds",
        "source_device",
        "client_session_id",
        "updated_at",
    )

    class Meta:
        model = models.Listening
        fields = (
            "id",
            "user",
            "track",
            "creation_date",
            "actor",
            "duration_seconds",
            "source_device",
            "client_session_id",
            "updated_at",
        )

    def create(self, validated_data):
        validated_data["user"] = self.context["user"]

        return super().create(validated_data)

    @extend_schema_field(federation_serializers.APIActorSerializer)
    def get_actor(self, obj):
        actor = obj.user.actor
        if actor:
            return federation_serializers.APIActorSerializer(actor).data

    def get_source_device(self, obj):
        if obj.source_device_id is None:
            return None
        return str(obj.source_device.uuid)

    def to_representation(self, instance):
        data = super().to_representation(instance)
        request = self.context.get("request")
        user = getattr(request, "user", None) if request else None
        is_owner = (
            user is not None
            and getattr(user, "is_authenticated", False)
            and instance.user_id is not None
            and instance.user_id == user.id
        )
        if not is_owner:
            for key in self.RICH_FIELDS:
                data.pop(key, None)
        return data


class ListeningWriteSerializer(serializers.ModelSerializer):
    user = serializers.PrimaryKeyRelatedField(read_only=True)
    source_device = serializers.UUIDField(
        required=False, allow_null=True, write_only=True
    )
    client_session_id = serializers.UUIDField(required=False, allow_null=True)
    duration_seconds = serializers.IntegerField(
        required=False, allow_null=True, min_value=0, max_value=86400
    )
    creation_date = serializers.DateTimeField(required=False, allow_null=True)

    class Meta:
        model = models.Listening
        fields = (
            "id",
            "user",
            "track",
            "creation_date",
            "duration_seconds",
            "source_device",
            "client_session_id",
        )

    def validate_creation_date(self, value):
        """
        Always reject far-future dates.

        Past age limits are applied in create() only for true inserts, so a
        session re-POST that resends the original creation_date (crash recovery)
        can still reach the idempotent max-duration merge path.
        """
        if value is None:
            return value
        now = timezone.now()
        if value > now + _CREATION_DATE_WINDOW:
            # Field-level: raise a list so DRF places it under creation_date once.
            raise serializers.ValidationError(
                [
                    {
                        "code": "creation_date_in_future",
                        "detail": "Too far in the future",
                    }
                ]
            )
        return value

    def _assert_creation_date_not_too_old(self, value):
        if value is None:
            return
        if value < timezone.now() - _CREATION_DATE_WINDOW:
            raise_coded_validation_error(
                "creation_date",
                "creation_date_too_old",
                "Use bulk import for historical listens",
            )

    def _merge_existing_session(self, user, session_id, validated_data):
        existing = (
            models.Listening.objects.select_for_update()
            .select_related("source_device")
            .get(user=user, client_session_id=session_id)
        )
        incoming = validated_data.get("duration_seconds")
        update_fields = []
        if incoming is not None:
            existing.duration_seconds = max(existing.duration_seconds or 0, incoming)
            update_fields.append("duration_seconds")
        if "source_device" in validated_data and validated_data["source_device"]:
            existing.source_device = validated_data["source_device"]
            update_fields.append("source_device")
        if update_fields:
            update_fields.append("updated_at")
            existing.save(update_fields=update_fields)
        existing._rich_created = False
        return existing

    def create(self, validated_data):
        user = self.context["user"]
        validated_data["user"] = user
        device_uuid = validated_data.pop("source_device", serializers.empty)
        if device_uuid is not serializers.empty and device_uuid is not None:
            validated_data["source_device"] = resolve_source_device(user, device_uuid)
        session_id = validated_data.get("client_session_id")
        creation_date = validated_data.get("creation_date")

        # Session already known: skip insert age gate and merge (recovery path).
        if session_id and models.Listening.objects.filter(
            user=user, client_session_id=session_id
        ).exists():
            with transaction.atomic():
                return self._merge_existing_session(user, session_id, validated_data)

        # True insert: enforce past window (future already validated).
        self._assert_creation_date_not_too_old(creation_date)

        try:
            with transaction.atomic():
                instance = super().create(validated_data)
                instance._rich_created = True
                return instance
        except IntegrityError as exc:
            if not session_id:
                raise
            # Race: concurrent insert for same session won the unique constraint.
            # New atomic block required after IntegrityError rolled back the insert.
            try:
                with transaction.atomic():
                    return self._merge_existing_session(
                        user, session_id, validated_data
                    )
            except models.Listening.DoesNotExist:
                # IntegrityError was not from our session unique constraint.
                raise exc from None

    def to_representation(self, instance):
        data = super().to_representation(instance)
        # source_device is write_only; surface UUID string (or null) on create response
        if instance.source_device_id is None:
            data["source_device"] = None
        else:
            data["source_device"] = str(instance.source_device.uuid)
        return data


class ListeningCreateResponseSerializer(serializers.Serializer):
    """
    OpenAPI response for POST /history/listenings/ (create + idempotent re-POST).

    Wire format is flat PKs (not nested track/user/actor from ListeningSerializer).
    """

    id = serializers.IntegerField()
    user = serializers.IntegerField()
    track = serializers.IntegerField()
    creation_date = serializers.DateTimeField()
    duration_seconds = serializers.IntegerField(allow_null=True)
    source_device = serializers.UUIDField(allow_null=True)
    client_session_id = serializers.UUIDField(allow_null=True)


class ListeningUpdateSerializer(serializers.ModelSerializer):
    """
    PATCH body for duration / device updates.

    Mutable: duration_seconds (monotonic max), optional source_device UUID.
    Read-only / ignored on write: track, user, creation_date, client_session_id.
    """

    source_device = serializers.UUIDField(
        required=False, allow_null=True, write_only=True
    )
    duration_seconds = serializers.IntegerField(
        required=False, allow_null=True, min_value=0, max_value=86400
    )

    class Meta:
        model = models.Listening
        fields = (
            "id",
            "duration_seconds",
            "source_device",
            "client_session_id",
            "updated_at",
        )
        read_only_fields = ("id", "client_session_id", "updated_at")

    def update(self, instance, validated_data):
        """
        Re-fetch under select_for_update so concurrent PATCH / session re-POST
        cannot lose a higher duration (monotonic-safe).
        """
        user = self.context["user"]
        with transaction.atomic():
            locked = (
                models.Listening.objects.select_for_update()
                .select_related("source_device")
                .get(pk=instance.pk)
            )
            update_fields = []

            if "duration_seconds" in validated_data:
                incoming = validated_data["duration_seconds"]
                if incoming is not None:
                    locked.duration_seconds = max(
                        locked.duration_seconds or 0, incoming
                    )
                    update_fields.append("duration_seconds")

            if "source_device" in validated_data:
                device_uuid = validated_data["source_device"]
                # Only apply when a UUID is provided; null means no change.
                if device_uuid is not None:
                    locked.source_device = resolve_source_device(user, device_uuid)
                    update_fields.append("source_device")

            if update_fields:
                update_fields.append("updated_at")
                locked.save(update_fields=update_fields)
            return locked

    def to_representation(self, instance):
        data = super().to_representation(instance)
        if instance.source_device_id is None:
            data["source_device"] = None
        else:
            # Prefer already-selected relation when available.
            data["source_device"] = str(instance.source_device.uuid)
        return data


class ListeningUpdateResponseSerializer(serializers.Serializer):
    """
    OpenAPI response for PATCH listening (by id or by-session).

    ``source_device`` is present as a readable UUID|null on the wire even though
    the request body marks it write_only for spectacular input schemas.
    """

    id = serializers.IntegerField()
    duration_seconds = serializers.IntegerField(allow_null=True)
    source_device = serializers.UUIDField(allow_null=True)
    client_session_id = serializers.UUIDField(allow_null=True)
    updated_at = serializers.DateTimeField()

class ListeningBulkItemSerializer(serializers.Serializer):
    track = serializers.IntegerField()
    # Required: historical import timestamps; omitting collapses same-track rows.
    creation_date = serializers.DateTimeField(required=True, allow_null=False)
    duration_seconds = serializers.IntegerField(
        required=False, allow_null=True, min_value=0, max_value=86400
    )
    source_device = serializers.UUIDField(required=False, allow_null=True)
    client_session_id = serializers.UUIDField(required=False, allow_null=True)


class ListeningBulkSerializer(serializers.Serializer):
    """Request body for POST /history/listenings/bulk/."""

    mode = serializers.ChoiceField(
        choices=("enrich_or_create", "create_only"),
        default="enrich_or_create",
        required=False,
    )
    items = ListeningBulkItemSerializer(
        many=True,
        error_messages={
            "required": "items is required",
            "null": "items is required",
            "not_a_list": "items must be a list",
        },
    )
    dedup_window_seconds = serializers.IntegerField(
        required=False,
        default=bulk_module.DEFAULT_DEDUP_WINDOW_SECONDS,
        min_value=0,
        max_value=3600,
    )
    # Not exposed for use; true is rejected so historical import cannot fan out.
    trigger_side_effects = serializers.BooleanField(required=False, default=False)

    def validate_items(self, value):
        if not value:
            raise serializers.ValidationError(
                [{"code": "empty_items", "detail": "items must not be empty"}]
            )
        if len(value) > bulk_module.BULK_MAX_ITEMS:
            raise serializers.ValidationError(
                [
                    {
                        "code": "batch_too_large",
                        "detail": (
                            f"Maximum {bulk_module.BULK_MAX_ITEMS} items per request"
                        ),
                    }
                ]
            )
        return value

    def validate_trigger_side_effects(self, value):
        if value:
            raise serializers.ValidationError(
                [
                    {
                        "code": "side_effects_not_allowed",
                        "detail": "Bulk import cannot trigger plugins or activity",
                    }
                ]
            )
        return value

    def validate(self, attrs):
        # Missing items: structured code (field-required path bypasses validate_items).
        if "items" not in attrs and "items" not in self.initial_data:
            raise serializers.ValidationError(
                {
                    "items": [
                        {
                            "code": "empty_items",
                            "detail": "items must not be empty",
                        }
                    ]
                }
            )
        return attrs

    def to_internal_value(self, data):
        # Normalize missing/null items into the same coded empty_items shape.
        if not isinstance(data, dict):
            return super().to_internal_value(data)
        if "items" not in data or data.get("items") is None:
            raise serializers.ValidationError(
                {
                    "items": [
                        {
                            "code": "empty_items",
                            "detail": "items must not be empty",
                        }
                    ]
                }
            )
        return super().to_internal_value(data)


class ListeningBulkResultSerializer(serializers.Serializer):
    created = serializers.IntegerField()
    enriched = serializers.IntegerField()
    skipped_duplicate = serializers.IntegerField()
    errors = serializers.ListField(child=serializers.DictField())


class ListeningStatsTopTrackSerializer(serializers.Serializer):
    track_id = serializers.IntegerField()
    title = serializers.CharField(allow_null=True)
    artist_name = serializers.CharField(allow_null=True)
    cover_url = serializers.CharField(allow_null=True)
    count = serializers.IntegerField()
    total_seconds = serializers.IntegerField()


class ListeningStatsTopArtistSerializer(serializers.Serializer):
    artist_id = serializers.IntegerField()
    name = serializers.CharField(allow_null=True)
    cover_url = serializers.CharField(allow_null=True)
    count = serializers.IntegerField()
    total_seconds = serializers.IntegerField()


class ListeningStatsTopAlbumSerializer(serializers.Serializer):
    album_id = serializers.IntegerField()
    title = serializers.CharField(allow_null=True)
    artist_name = serializers.CharField(allow_null=True)
    cover_url = serializers.CharField(allow_null=True)
    count = serializers.IntegerField()
    total_seconds = serializers.IntegerField()


class ListeningStatsMonthSerializer(serializers.Serializer):
    month = serializers.IntegerField()
    count = serializers.IntegerField()
    total_seconds = serializers.IntegerField()


class ListeningStatsDeviceSerializer(serializers.Serializer):
    device_uuid = serializers.UUIDField(allow_null=True)
    device_name = serializers.CharField(allow_null=True)
    count = serializers.IntegerField()
    total_seconds = serializers.IntegerField()


class ListeningStatsSerializer(serializers.Serializer):
    """OpenAPI schema for GET /history/listenings/stats/."""

    year = serializers.IntegerField()
    total_listens = serializers.IntegerField()
    total_seconds = serializers.IntegerField()
    listens_with_duration = serializers.IntegerField()
    estimated_seconds = serializers.IntegerField()
    unique_tracks = serializers.IntegerField()
    unique_artists = serializers.IntegerField()
    unique_albums = serializers.IntegerField()
    top_tracks = ListeningStatsTopTrackSerializer(many=True)
    top_artists = ListeningStatsTopArtistSerializer(many=True)
    top_albums = ListeningStatsTopAlbumSerializer(many=True)
    monthly = ListeningStatsMonthSerializer(many=True)
    by_device = ListeningStatsDeviceSerializer(many=True)
