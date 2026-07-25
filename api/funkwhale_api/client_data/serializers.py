import json

from rest_framework import serializers

from . import models
from .sensitive import is_sensitive_key

# Hard caps from rich-client-data design
MAX_KEYS_PER_SCOPE = 200
MAX_VALUE_BYTES = 8 * 1024  # 8 KiB per value
MAX_PAYLOAD_BYTES = 256 * 1024  # 256 KiB total payload


def raise_coded(field, code, detail):
    """Field-scoped structured validation error: field → list of {code, detail}."""
    raise serializers.ValidationError({field: [{"code": code, "detail": detail}]})


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
        return str(models.ClientDevice.objects.values_list("uuid", flat=True).get(pk=obj.device_id))


class ClientPreferenceWriteSerializer(serializers.Serializer):
    """PUT body for merge/replace of a preference scope."""

    client_id = serializers.CharField(max_length=64)
    device_uuid = serializers.UUIDField(required=False, allow_null=True, default=None)
    preferences = serializers.DictField(child=serializers.JSONField(), allow_empty=True)
    mode = serializers.ChoiceField(choices=["merge", "replace"], default="merge")

    def validate_preferences(self, value):
        if not isinstance(value, dict):
            raise_coded(
                "preferences",
                "invalid_preferences",
                "preferences must be an object mapping keys to JSON values",
            )

        # Per-key sensitivity and value size
        for key, pref_value in value.items():
            if not isinstance(key, str) or not key:
                raise_coded(
                    "preferences",
                    "invalid_key",
                    "Preference keys must be non-empty strings",
                )
            if len(key) > 255:
                raise_coded(
                    "preferences",
                    "invalid_key",
                    f"Preference key exceeds 255 characters: {key[:32]}…",
                )
            if is_sensitive_key(key):
                raise_coded(
                    "preferences",
                    "sensitive_key_rejected",
                    f"Preference key '{key}' is not allowed (sensitive)",
                )
            # Measure JSON encoding size of the value
            try:
                encoded = json.dumps(
                    pref_value, separators=(",", ":"), ensure_ascii=False
                )
            except (TypeError, ValueError):
                raise_coded(
                    "preferences",
                    "invalid_value",
                    f"Preference value for '{key}' is not JSON-serializable",
                )
            value_bytes = len(encoded.encode("utf-8"))
            if value_bytes > MAX_VALUE_BYTES:
                raise_coded(
                    "preferences",
                    "value_too_large",
                    f"Preference value for '{key}' exceeds {MAX_VALUE_BYTES} bytes",
                )

        if len(value) > MAX_KEYS_PER_SCOPE:
            raise_coded(
                "preferences",
                "too_many_keys",
                f"At most {MAX_KEYS_PER_SCOPE} keys per scope (got {len(value)})",
            )

        return value

    def validate(self, attrs):
        # Total payload size of preferences object
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
        except (TypeError, ValueError):
            raise_coded(
                "preferences",
                "invalid_preferences",
                "preferences must be JSON-serializable",
            )
        return attrs
