from django.contrib import admin

from . import models


@admin.register(models.ShareLink)
class ShareLinkAdmin(admin.ModelAdmin):
    list_display = (
        "uuid",
        "object_type",
        "object_id",
        "owner",
        "creation_date",
        "expiration_date",
        "revoked_at",
    )
    list_filter = ("object_type",)
    search_fields = ("token", "label", "owner__username")
    readonly_fields = ("uuid", "token", "creation_date")
    raw_id_fields = ("owner",)
