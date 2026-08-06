import django_filters
from django import forms
from django.db.models import Q
from django_filters import rest_framework as filters

from funkwhale_api.audio import models as audio_models
from funkwhale_api.common import fields, search
from funkwhale_api.music import models as music_models
from funkwhale_api.tags import models as tags_models
from funkwhale_api.users import models as users_models


class ManageChannelFilterSet(filters.FilterSet):
    q = fields.SmartSearchFilter(
        config=search.SearchConfig(
            search_fields={
                "name": {"to": "artist__name"},
                "username": {"to": "artist__name"},
                "rss": {"to": "rss_url"},
            },
            filter_fields={
                "uuid": {"to": "uuid"},
                "category": {"to": "artist__content_category"},
                "tag": {"to": "artist__tagged_items__tag__name", "distinct": True},
            },
        )
    )

    class Meta:
        model = audio_models.Channel
        fields = []


class ManageArtistFilterSet(filters.FilterSet):
    q = fields.SmartSearchFilter(
        config=search.SearchConfig(
            search_fields={
                "name": {"to": "name"},
                "mbid": {"to": "mbid"},
            },
            filter_fields={
                "uuid": {"to": "uuid"},
                "library_id": {
                    "to": "tracks__uploads__library_id",
                    "field": forms.IntegerField(),
                    "distinct": True,
                },
                "category": {"to": "content_category"},
                "tag": {"to": "tagged_items__tag__name", "distinct": True},
            },
        )
    )

    class Meta:
        model = music_models.Artist
        fields = ["name", "mbid", "content_category"]


class ManageAlbumFilterSet(filters.FilterSet):
    q = fields.SmartSearchFilter(
        config=search.SearchConfig(
            search_fields={
                "title": {"to": "title"},
                "artist": {"to": "artist_credit__artist__name"},
                "mbid": {"to": "mbid"},
            },
            filter_fields={
                "uuid": {"to": "uuid"},
                "artist_id": {
                    "to": "artist_credit__artist_id",
                    "field": forms.IntegerField(),
                    "distinct": True,
                },
                "library_id": {
                    "to": "tracks__uploads__library_id",
                    "field": forms.IntegerField(),
                    "distinct": True,
                },
                "tag": {"to": "tagged_items__tag__name", "distinct": True},
            },
        )
    )

    class Meta:
        model = music_models.Album
        fields = ["title", "mbid"]


class ManageTrackFilterSet(filters.FilterSet):
    q = fields.SmartSearchFilter(
        config=search.SearchConfig(
            search_fields={
                "title": {"to": "title"},
                "mbid": {"to": "mbid"},
                "artist": {"to": "artist_credit__artist__name"},
                "album": {"to": "album__title"},
                "album_artist": {"to": "album__artist_credit__artist__name"},
                "copyright": {"to": "copyright"},
            },
            filter_fields={
                "album_id": {"to": "album_id", "field": forms.IntegerField()},
                "album_artist_id": {
                    "to": "album__artist_credit__artist_id",
                    "field": forms.IntegerField(),
                },
                "artist_id": {
                    "to": "artist_credit__artist_id",
                    "field": forms.IntegerField(),
                    "distinct": True,
                },
                "uuid": {"to": "uuid"},
                "license": {"to": "license"},
                "library_id": {
                    "to": "uploads__library_id",
                    "field": forms.IntegerField(),
                    "distinct": True,
                },
                "tag": {"to": "tagged_items__tag__name", "distinct": True},
            },
        )
    )

    class Meta:
        model = music_models.Track
        fields = ["title", "mbid", "album", "license"]


class ManageLibraryFilterSet(filters.FilterSet):
    ordering = django_filters.OrderingFilter(
        # tuple-mapping retains order
        fields=(
            ("creation_date", "creation_date"),
            ("_uploads_count", "uploads_count"),
            ("followers_count", "followers_count"),
        )
    )
    q = fields.SmartSearchFilter(
        config=search.SearchConfig(
            search_fields={
                "name": {"to": "name"},
                "description": {"to": "description"},
            },
            filter_fields={
                "uuid": {"to": "uuid"},
                "artist_id": {
                    "to": "uploads__track__artist_credit__artist_id",
                    "field": forms.IntegerField(),
                    "distinct": True,
                },
                "album_id": {
                    "to": "uploads__track__album_id",
                    "field": forms.IntegerField(),
                    "distinct": True,
                },
                "track_id": {
                    "to": "uploads__track__id",
                    "field": forms.IntegerField(),
                    "distinct": True,
                },
                "privacy_level": {"to": "privacy_level"},
            },
        )
    )

    class Meta:
        model = music_models.Library
        fields = ["name", "privacy_level"]


class ManageUploadFilterSet(filters.FilterSet):
    ordering = django_filters.OrderingFilter(
        # tuple-mapping retains order
        fields=(
            ("creation_date", "creation_date"),
            ("modification_date", "modification_date"),
            ("accessed_date", "accessed_date"),
            ("size", "size"),
            ("bitrate", "bitrate"),
            ("duration", "duration"),
        )
    )
    q = fields.SmartSearchFilter(
        config=search.SearchConfig(
            search_fields={
                "source": {"to": "source"},
                "track": {"to": "track__title"},
                "album": {"to": "track__album__title"},
                "artist": {"to": "track__artist_credit__artist__name"},
            },
            filter_fields={
                "uuid": {"to": "uuid"},
                "library_id": {"to": "library_id", "field": forms.IntegerField()},
                "artist_id": {
                    "to": "track__artist_credit__artist_id",
                    "field": forms.IntegerField(),
                },
                "album_id": {"to": "track__album_id", "field": forms.IntegerField()},
                "track_id": {"to": "track__id", "field": forms.IntegerField()},
                "import_reference": {"to": "import_reference"},
                "type": {"to": "mimetype"},
                "status": {"to": "import_status"},
                "privacy_level": {"to": "library__privacy_level"},
            },
        )
    )
    privacy_level = filters.CharFilter("library__privacy_level")

    class Meta:
        model = music_models.Upload
        fields = [
            "mimetype",
            "import_reference",
            "import_status",
        ]


def filter_allowed(queryset, name, value):
    """
    If value=false, we want to include object with value=null as well
    """
    if value:
        return queryset.filter(allowed=True)
    else:
        return queryset.filter(Q(allowed=False) | Q(allowed__isnull=True))


class ManageUserFilterSet(filters.FilterSet):
    q = fields.SmartSearchFilter(
        config=search.SearchConfig(
            search_fields={
                "name": {"to": "name"},
                "username": {"to": "username"},
                "email": {"to": "email"},
            }
        )
    )

    class Meta:
        model = users_models.User
        fields = [
            "is_active",
            "privacy_level",
            "is_staff",
            "is_superuser",
            "permission_library",
            "permission_settings",
            "permission_moderation",
        ]


class ManageInvitationFilterSet(filters.FilterSet):
    q = fields.SearchFilter(search_fields=["owner__username", "code", "owner__email"])
    is_open = filters.BooleanFilter(method="filter_is_open")

    class Meta:
        model = users_models.Invitation
        fields = []

    def filter_is_open(self, queryset, field_name, value):
        if value is None:
            return queryset
        return queryset.open(value)


class ManageTagFilterSet(filters.FilterSet):
    q = fields.SearchFilter(search_fields=["name"])

    class Meta:
        model = tags_models.Tag
        fields = []
