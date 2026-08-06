from funkwhale_api.common import admin

from . import models


@admin.register(models.Channel)
class ChannelAdmin(admin.ModelAdmin):
    list_display = [
        "uuid",
        "artist",
        "owner",
        "library",
        "creation_date",
    ]
