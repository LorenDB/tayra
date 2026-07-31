from rest_framework import serializers

from .. import models
from .scopes import OAUTH_APP_SCOPES, SCOPES_BY_ID


class ApplicationSerializer(serializers.ModelSerializer):
    scopes = serializers.CharField(source="scope")

    class Meta:
        model = models.Application
        fields = ["client_id", "name", "scopes", "created", "updated"]

    def to_representation(self, obj):
        repr = super().to_representation(obj)
        # The application token is a bearer credential: it must only be
        # returned once, at creation or rotation time (see views.py).
        if obj.user_id and self.context.get("include_token"):
            repr["token"] = obj.token
        return repr


class CreateApplicationSerializer(serializers.ModelSerializer):
    name = serializers.CharField(required=True, max_length=255)
    scopes = serializers.CharField(source="scope", default="read")

    class Meta:
        model = models.Application
        fields = [
            "client_id",
            "name",
            "scopes",
            "client_secret",
            "created",
            "updated",
            "redirect_uris",
        ]
        read_only_fields = ["client_id", "created", "updated"]

    def validate_scopes(self, value):
        scope_ids = value.split()
        unknown = [s for s in scope_ids if s not in SCOPES_BY_ID]
        if unknown:
            raise serializers.ValidationError(
                "Unknown scopes: " + ", ".join(unknown)
            )
        # Parent scopes ("read"/"write") are allowed: their privileged
        # leaves are stripped at request time by ScopePermission, which
        # intersects them with the owner's permissions and OAUTH_APP_SCOPES.
        # Explicit privileged leaves are rejected right here.
        privileged = [
            s for s in scope_ids if s not in ("read", "write")
            and s not in OAUTH_APP_SCOPES
        ]
        if privileged:
            raise serializers.ValidationError(
                "These scopes are not allowed: " + ", ".join(sorted(privileged))
            )
        return value

    def to_representation(self, obj):
        repr = super().to_representation(obj)
        # The application token is a bearer credential: it must only be
        # returned once, at creation or rotation time (see views.py).
        if obj.user_id and self.context.get("include_token"):
            repr["token"] = obj.token
        return repr
