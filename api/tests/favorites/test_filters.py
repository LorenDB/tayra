from funkwhale_api.favorites import filters, models


def test_track_favorite_filter_scope(factories, mocker, queryset_equal_list):
    user = factories["users.User"]()
    own = factories["favorites.TrackFavorite"](user=user)
    factories["favorites.TrackFavorite"]()
    qs = models.TrackFavorite.objects.all()
    filterset = filters.TrackFavoriteFilter(
        {"scope": "me"}, request=mocker.Mock(user=user), queryset=qs
    )

    assert filterset.qs == [own]
