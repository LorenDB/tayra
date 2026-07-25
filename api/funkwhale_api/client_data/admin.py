from funkwhale_api.common import admin

from . import models


@admin.register(models.ClientDevice)
class ClientDeviceAdmin(admin.ModelAdmin):
    list_display = [
        "uuid",
        "user",
        "name",
        "client_id",
        "client_version",
        "is_active",
        "last_seen_at",
        "created_at",
    ]
    list_filter = ["is_active", "client_id"]
    search_fields = ["name", "uuid", "user__username", "client_id"]
    list_select_related = ["user"]
    # Identity fields are immutable in admin (API uses client-generated uuid).
    readonly_fields = ["uuid", "created_at"]


@admin.register(models.ClientPreference)
class ClientPreferenceAdmin(admin.ModelAdmin):
    list_display = ["user", "client_id", "key", "device", "updated_at"]
    list_filter = ["client_id"]
    search_fields = ["key", "client_id", "user__username"]
    list_select_related = ["user", "device"]
    readonly_fields = ["updated_at"]
