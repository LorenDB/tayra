import datetime
import json
import uuid as uuid_mod

from django.utils import timezone
from rest_framework import serializers

from funkwhale_api.music.models import Track

from . import models
from .sensitive import is_sensitive_key

# Hard caps from rich-client-data design
MAX_KEYS_PER_SCOPE = 200
MAX_VALUE_BYTES = 8 * 1024  # 8 KiB per value
MAX_PAYLOAD_BYTES = 256 * 1024  # 256 KiB preferences object (not whole HTTP body)
BULK_MAX_ITEMS = 500
# Client clocks may skew; reject timestamps further ahead than this.
UPDATED_AT_FUTURE_SKEW = datetime.timedelta(minutes=5)


def raise_coded(field, code, detail):
    """
    Field-scoped structured validation error for view-level / validate() use:
    ``{field: [{code, detail}]}``.
    """
    raise serializers.ValidationError({field: [{"code": code, "detail": detail}]})


def raise_coded_list(code, detail):
    """
    Structured error for ``validate_<field>`` methods (DRF wraps under the field name):
    results in ``{field: [{code, detail}]}``.
    """
    raise serializers.ValidationError([{"code": code, "detail": detail}])


def validate_updated_at_skew(value):
    """Reject updated_at more than UPDATED_AT_FUTURE_SKEW ahead of server now."""
    if value is None:
        return value
    if value > timezone.now() + UPDATED_AT_FUTURE_SKEW:
        raise_coded(
            "updated_at",
            "updated_at_in_future",
            "updated_at is more than 5 minutes ahead of server time",
        )
    return value


def resolve_source_device(user, device_uuid):
    """
    Map client UUID → active ClientDevice for user.
    Returns None if device_uuid is None. Raises coded ValidationError otherwise.
    """
    if device_uuid is None:
        return None
    try:
        device = models.ClientDevice.objects.get(user=user, uuid=device_uuid)
    except models.ClientDevice.DoesNotExist:
        raise_coded(
            "source_device",
            "device_not_registered",
            "Register the device via POST /api/v1/client-devices/",
        )
    if not device.is_active:
        raise_coded(
            "source_device",
            "device_inactive",
            "Device is soft-deleted; re-register or reactivate it",
        )
    return device


def apply_progress_fields(instance, data, user, *, set_updated_at=True):
    """
    Mutate a PlaybackProgress instance from validated write data.

    Only keys present in ``data`` are applied (partial merge for optional fields).
    ``completed`` sticky rule:
      - if ``completed`` present: honor True; honor False unless threshold auto-promotes
      - if omitted: keep existing ``instance.completed`` and still auto-promote at ≥90%
    """
    device_uuid = data.get("source_device", serializers.empty)
    if device_uuid is not serializers.empty:
        instance.source_device = resolve_source_device(user, device_uuid)

    if "position_ms" in data:
        instance.position_ms = data["position_ms"]
    if "duration_ms" in data:
        instance.duration_ms = data["duration_ms"]
    if "channel_uuid" in data:
        instance.channel_uuid = data["channel_uuid"]

    if "completed" in data:
        client_completed = data["completed"]
    else:
        # Sticky: preserve mark-as-played; still allow threshold auto-promote.
        client_completed = bool(instance.completed)

    instance.completed = models.PlaybackProgress.resolve_completed(
        instance.position_ms,
        instance.duration_ms,
        client_completed=client_completed,
    )

    if set_updated_at:
        instance.updated_at = data.get("updated_at") or timezone.now()
    return instance


def ensure_track_exists(track_id):
    if not Track.objects.filter(pk=track_id).exists():
        raise_coded("track", "track_not_found", f"Track {track_id} does not exist")


class ClientDeviceSerializer(serializers.ModelSerializer):
    class Meta:
        model = models.ClientDevice
        fields = (
            "uuid",
            "name",
            "client_id",
            "client_version",
            "last_seen_at",
            "created_at",
            "is_active",
        )
        read_only_fields = ("last_seen_at", "created_at")

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        if self.instance is not None:
            # PATCH: rename / set is_active only
            for field in ("uuid", "client_id", "client_version"):
                self.fields[field].read_only = True
        else:
            # POST create/upsert: is_active always forced True on upsert
            self.fields["is_active"].read_only = True


class ClientPreferenceSerializer(serializers.ModelSerializer):
    """Read representation of a single preference row."""

    device_uuid = serializers.SerializerMethodField()

    class Meta:
        model = models.ClientPreference
        fields = ("key", "value", "updated_at", "device_uuid")

    def get_device_uuid(self, obj):
        if obj.device_id is None:
            return None
        device = getattr(obj, "device", None)
        if device is not None:
            return str(device.uuid)
        # Fallback if not select_related (should be rare)
        return str(
            models.ClientDevice.objects.values_list("uuid", flat=True).get(
                pk=obj.device_id
            )
        )


class ClientPreferenceWriteSerializer(serializers.Serializer):
    """PUT body for merge/replace of a preference scope."""

    client_id = serializers.CharField(max_length=64)
    # CharField so invalid UUIDs use raise_coded (same shape as GET), not stock DRF.
    device_uuid = serializers.CharField(
        required=False, allow_null=True, allow_blank=True, default=None
    )
    preferences = serializers.DictField(child=serializers.JSONField(), allow_empty=True)
    mode = serializers.ChoiceField(choices=["merge", "replace"], default="merge")

    def validate_device_uuid(self, value):
        if value in (None, ""):
            return None
        try:
            return uuid_mod.UUID(str(value))
        except (ValueError, TypeError, AttributeError):
            raise_coded_list(
                "invalid",
                "device_uuid must be a valid UUID",
            )

    def validate_preferences(self, value):
        if not isinstance(value, dict):
            raise_coded_list(
                "invalid_preferences",
                "preferences must be an object mapping keys to JSON values",
            )

        # Per-key sensitivity and value size
        for key, pref_value in value.items():
            if not isinstance(key, str) or not key:
                raise_coded_list(
                    "invalid_key",
                    "Preference keys must be non-empty strings",
                )
            if len(key) > 255:
                raise_coded_list(
                    "invalid_key",
                    f"Preference key exceeds 255 characters: {key[:32]}…",
                )
            if is_sensitive_key(key):
                raise_coded_list(
                    "sensitive_key_rejected",
                    f"Preference key '{key}' is not allowed (sensitive)",
                )
            # Measure JSON encoding size of the value
            try:
                encoded = json.dumps(
                    pref_value, separators=(",", ":"), ensure_ascii=False
                )
            except (TypeError, ValueError):
                raise_coded_list(
                    "invalid_value",
                    f"Preference value for '{key}' is not JSON-serializable",
                )
            value_bytes = len(encoded.encode("utf-8"))
            if value_bytes > MAX_VALUE_BYTES:
                raise_coded_list(
                    "value_too_large",
                    f"Preference value for '{key}' exceeds {MAX_VALUE_BYTES} bytes",
                )

        if len(value) > MAX_KEYS_PER_SCOPE:
            raise_coded_list(
                "too_many_keys",
                f"At most {MAX_KEYS_PER_SCOPE} keys per scope (got {len(value)})",
            )

        return value

    def validate(self, attrs):
        # Total payload size of the preferences object only (design: 256 KiB).
        try:
            payload = json.dumps(
                attrs.get("preferences") or {},
                separators=(",", ":"),
                ensure_ascii=False,
            )
            if len(payload.encode("utf-8")) > MAX_PAYLOAD_BYTES:
                raise_coded(
                    "preferences",
                    "payload_too_large",
                    f"Preferences payload exceeds {MAX_PAYLOAD_BYTES} bytes",
                )
        except serializers.ValidationError:
            raise
        except (TypeError, ValueError):
            raise_coded(
                "preferences",
                "invalid_preferences",
                "preferences must be JSON-serializable",
            )
        return attrs


class ClientPreferenceListResponseSerializer(serializers.Serializer):
    """OpenAPI schema for GET /client-preferences/."""

    count = serializers.IntegerField()
    results = ClientPreferenceSerializer(many=True)


class ClientPreferenceWriteResponseSerializer(serializers.Serializer):
    """OpenAPI schema for PUT /client-preferences/ (written scope only)."""

    client_id = serializers.CharField()
    device_uuid = serializers.UUIDField(allow_null=True)
    mode = serializers.ChoiceField(choices=["merge", "replace"])
    resolved = serializers.BooleanField()
    count = serializers.IntegerField()
    results = ClientPreferenceSerializer(many=True)


class PlaybackProgressSerializer(serializers.ModelSerializer):
    """Read representation; source_device is the device UUID string."""

    source_device = serializers.SerializerMethodField()
    track = serializers.IntegerField(source="track_id", read_only=True)

    class Meta:
        model = models.PlaybackProgress
        fields = (
            "track",
            "channel_uuid",
            "position_ms",
            "duration_ms",
            "completed",
            "updated_at",
            "source_device",
        )

    def get_source_device(self, obj):
        if obj.source_device_id is None:
            return None
        return str(obj.source_device.uuid)


class PlaybackProgressWriteSerializer(serializers.Serializer):
    """Body for single-track PUT upsert (track comes from URL)."""

    position_ms = serializers.IntegerField(min_value=0)
    duration_ms = serializers.IntegerField(
        min_value=0, required=False, allow_null=True
    )
    # No default: omit preserves sticky completed on the server row.
    completed = serializers.BooleanField(required=False)
    channel_uuid = serializers.UUIDField(required=False, allow_null=True)
    source_device = serializers.UUIDField(required=False, allow_null=True)
    updated_at = serializers.DateTimeField(required=False)

    def validate_updated_at(self, value):
        return validate_updated_at_skew(value)


class PlaybackProgressBulkItemSerializer(serializers.Serializer):
    track = serializers.IntegerField(min_value=1)
    position_ms = serializers.IntegerField(min_value=0)
    duration_ms = serializers.IntegerField(
        min_value=0, required=False, allow_null=True
    )
    # No default: omit preserves sticky completed on existing rows.
    completed = serializers.BooleanField(required=False)
    channel_uuid = serializers.UUIDField(required=False, allow_null=True)
    source_device = serializers.UUIDField(required=False, allow_null=True)
    updated_at = serializers.DateTimeField(required=False)

    def validate_updated_at(self, value):
        return validate_updated_at_skew(value)


class PlaybackProgressBulkSerializer(serializers.Serializer):
    items = PlaybackProgressBulkItemSerializer(many=True)

    def validate_items(self, value):
        if not value:
            raise serializers.ValidationError(
                [{"code": "empty_batch", "detail": "items must not be empty"}]
            )
        if len(value) > BULK_MAX_ITEMS:
            # Field-level validator: raise list (not field-keyed dict) to avoid nesting.
            raise serializers.ValidationError(
                [
                    {
                        "code": "batch_too_large",
                        "detail": f"Maximum {BULK_MAX_ITEMS} items per request",
                    }
                ]
            )
        return value


class PlaybackProgressBulkResultSerializer(serializers.Serializer):
    """OpenAPI schema for POST /playback-progress/bulk/."""

    created = serializers.IntegerField()
    updated = serializers.IntegerField()
    skipped = serializers.IntegerField()
    errors = serializers.ListField(child=serializers.DictField())


class PlaybackProgressConflictSerializer(serializers.Serializer):
    """OpenAPI schema for PUT 409 progress_conflict."""

    code = serializers.CharField()
    detail = serializers.CharField()
    progress = PlaybackProgressSerializer()
