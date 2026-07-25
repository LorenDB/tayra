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
