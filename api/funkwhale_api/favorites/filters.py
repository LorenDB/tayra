from django_filters import rest_framework as filters

from funkwhale_api.common import fields
from funkwhale_api.common import filters as common_filters

from . import models


class TrackFavoriteFilter(filters.FilterSet):
    q = fields.SearchFilter(
        search_fields=[
            "track__title",
            "track__artist_credit__artist__name",
            "track__album__title",
        ]
    )
    scope = common_filters.ActorScopeFilter(user_field="user", distinct=True)

    class Meta:
        model = models.TrackFavorite
        fields = []
