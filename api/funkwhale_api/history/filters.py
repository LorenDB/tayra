import datetime

import django_filters
from django.utils import timezone

from funkwhale_api.common import filters as common_filters

from . import models


class ListeningFilter(django_filters.FilterSet):
    username = django_filters.CharFilter("user__username")
    scope = common_filters.ActorScopeFilter(user_field="user", distinct=True)
    track = django_filters.NumberFilter(field_name="track_id")
    creation_date_after = django_filters.IsoDateTimeFilter(
        field_name="creation_date", lookup_expr="gte"
    )
    creation_date_before = django_filters.IsoDateTimeFilter(
        field_name="creation_date", lookup_expr="lte"
    )
    year = django_filters.NumberFilter(method="filter_year")
    # Wire format: device UUID string → FK uuid column
    source_device = django_filters.UUIDFilter(field_name="source_device__uuid")
    # Default True: stock thin scrobbles are excluded unless rich_only=false.
    rich_only = django_filters.BooleanFilter(method="filter_rich_only")

    class Meta:
        model = models.Listening
        fields = []

    def filter_rich_only(self, queryset, name, value):
        """When true (default for list), exclude stock thin listenings."""
        if value is False:
            return queryset
        return queryset.rich()

    def filter_year(self, queryset, name, value):
        """Expand year=YYYY to [Jan 1, next Jan 1) in the active timezone.

        Out-of-range years (datetime supports 1..9999; we need year+1 for end)
        are ignored so user-controlled query params never 500.
        """
        if value is None:
            return queryset
        try:
            year = int(value)
        except (TypeError, ValueError):
            return queryset
        # datetime.datetime year range is 1..9999; end bound needs year+1.
        if year < 1 or year > 9998:
            return queryset
        try:
            tz = timezone.get_current_timezone()
            start = timezone.make_aware(datetime.datetime(year, 1, 1), tz)
            end = timezone.make_aware(datetime.datetime(year + 1, 1, 1), tz)
        except (ValueError, OverflowError):
            return queryset
        return queryset.filter(creation_date__gte=start, creation_date__lt=end)
