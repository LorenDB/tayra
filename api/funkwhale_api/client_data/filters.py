import django_filters
from django_filters import rest_framework as filters

from . import models


class PlaybackProgressFilter(filters.FilterSet):
    channel_uuid = django_filters.UUIDFilter()
    completed = django_filters.BooleanFilter()
    # Sync-friendly range: ?updated_at_after=…&updated_at_before=…
    updated_at = django_filters.IsoDateTimeFromToRangeFilter()

    class Meta:
        model = models.PlaybackProgress
        fields = ["channel_uuid", "completed", "updated_at"]
