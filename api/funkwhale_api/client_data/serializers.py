from rest_framework import serializers

from . import models


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
