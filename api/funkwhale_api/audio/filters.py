import django_filters
from django.db.models import Q

from funkwhale_api.common import fields
from funkwhale_api.common import filters as common_filters

from . import models


def filter_tags(queryset, name, value):
    non_empty_tags = [v.lower() for v in value if v]
    for tag in non_empty_tags:
        queryset = queryset.filter(artist__tagged_items__tag__name=tag).distinct()
    return queryset


TAG_FILTER = common_filters.MultipleQueryFilter(method=filter_tags)


class ChannelFilter(django_filters.FilterSet):
    q = fields.SearchFilter(search_fields=["artist__name"])
    tag = TAG_FILTER
    scope = common_filters.ActorScopeFilter(user_field="owner", distinct=True)
    subscribed = django_filters.BooleanFilter(
        field_name="_", method="filter_subscribed"
    )
    external = django_filters.BooleanFilter(field_name="_", method="filter_external")
    ordering = django_filters.OrderingFilter(
        # tuple-mapping retains order
        fields=(
            ("creation_date", "creation_date"),
            ("artist__modification_date", "modification_date"),
            ("?", "random"),
        )
    )

    class Meta:
        model = models.Channel
        fields = []

    def filter_subscribed(self, queryset, name, value):
        if not self.request.user.is_authenticated:
            return queryset.none()

        subscriptions = models.ChannelSubscription.objects.filter(
            user=self.request.user, approved=True
        )

        query = Q(pk__in=subscriptions.values_list("channel_id", flat=True))

        if value:
            return queryset.filter(query)
        else:
            return queryset.exclude(query)

    def filter_external(self, queryset, name, value):
        query = Q(is_external_rss=True)
        if value:
            queryset = queryset.filter(query)
        else:
            queryset = queryset.exclude(query)

        return queryset


class IncludeChannelsFilterSet(django_filters.FilterSet):
    """

    A filterset that include a "include_channels" param. Meant for compatibility
    with clients that don't support channels yet:

    - include_channels=false : exclude objects associated with a channel
    - include_channels=true : don't exclude objects associated with a channel
    - not specified: include_channels=false

    Usage:

    class MyFilterSet(IncludeChannelsFilterSet):
        class Meta:
            include_channels_field = "album__artist_credit__artist__channel"

    """

    include_channels = django_filters.BooleanFilter(
        field_name="_", method="filter_include_channels"
    )

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.data = self.data.copy()
        self.data.setdefault("include_channels", False)

    def filter_include_channels(self, queryset, name, value):
        if value is True:
            return queryset
        else:
            params = {self.__class__.Meta.include_channels_field: None}
            return queryset.filter(**params)
