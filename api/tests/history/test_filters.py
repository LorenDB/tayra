import datetime

from django.urls import reverse
from django.utils import timezone

from funkwhale_api.history import filters, models


def test_listening_filter_track_artist(factories, mocker, queryset_equal_list):
    factories["history.Listening"]()
    cf = factories["moderation.UserFilter"](for_artist=True)
    hidden_listening = factories["history.Listening"](track__artist=cf.target_artist)
    qs = models.Listening.objects.all()
    filterset = filters.ListeningFilter(
        {"hidden": "true"}, request=mocker.Mock(user=cf.user), queryset=qs
    )

    assert filterset.qs == [hidden_listening]


def test_listening_filter_track_album_artist(factories, mocker, queryset_equal_list):
    factories["history.Listening"]()
    cf = factories["moderation.UserFilter"](for_artist=True)
    hidden_listening = factories["history.Listening"](
        track__album__artist=cf.target_artist
    )
    qs = models.Listening.objects.all()
    filterset = filters.ListeningFilter(
        {"hidden": "true"}, request=mocker.Mock(user=cf.user), queryset=qs
    )

    assert filterset.qs == [hidden_listening]


def test_listening_filter_creation_date_range(factories, mocker, queryset_equal_list):
    early = factories["history.Listening"](
        creation_date=timezone.now() - datetime.timedelta(days=10)
    )
    mid = factories["history.Listening"](
        creation_date=timezone.now() - datetime.timedelta(days=5)
    )
    late = factories["history.Listening"](
        creation_date=timezone.now() - datetime.timedelta(days=1)
    )
    qs = models.Listening.objects.all()
    after = (timezone.now() - datetime.timedelta(days=7)).isoformat()
    before = (timezone.now() - datetime.timedelta(days=2)).isoformat()
    filterset = filters.ListeningFilter(
        {"creation_date_after": after, "creation_date_before": before},
        request=mocker.Mock(user=factories["users.User"]()),
        queryset=qs,
    )

    assert set(filterset.qs) == {mid}
    assert early not in filterset.qs
    assert late not in filterset.qs


def test_listening_filter_year(factories, mocker, queryset_equal_list):
    in_year = factories["history.Listening"](
        creation_date=timezone.make_aware(datetime.datetime(2025, 6, 15))
    )
    other_year = factories["history.Listening"](
        creation_date=timezone.make_aware(datetime.datetime(2024, 6, 15))
    )
    qs = models.Listening.objects.all()
    filterset = filters.ListeningFilter(
        {"year": "2025"},
        request=mocker.Mock(user=factories["users.User"]()),
        queryset=qs,
    )

    assert list(filterset.qs) == [in_year]
    assert other_year not in filterset.qs


def test_listening_filter_source_device_uuid(factories, mocker, queryset_equal_list):
    user = factories["users.User"]()
    device = factories["client_data.ClientDevice"](user=user)
    other_device = factories["client_data.ClientDevice"](user=user)
    match = factories["history.Listening"](user=user, source_device=device)
    factories["history.Listening"](user=user, source_device=other_device)
    factories["history.Listening"](user=user, source_device=None)

    qs = models.Listening.objects.all()
    filterset = filters.ListeningFilter(
        {"source_device": str(device.uuid)},
        request=mocker.Mock(user=user),
        queryset=qs,
    )

    assert list(filterset.qs) == [match]


def test_listening_filter_track(factories, mocker, queryset_equal_list):
    track = factories["music.Track"]()
    match = factories["history.Listening"](track=track)
    factories["history.Listening"]()
    qs = models.Listening.objects.all()
    filterset = filters.ListeningFilter(
        {"track": str(track.pk)},
        request=mocker.Mock(user=factories["users.User"]()),
        queryset=qs,
    )

    assert list(filterset.qs) == [match]


def test_listening_list_api_filters(factories, logged_in_api_client):
    """End-to-end list filters for date range, year, and device UUID."""
    user = logged_in_api_client.user
    device = factories["client_data.ClientDevice"](user=user)
    in_range = factories["history.Listening"](
        user=user,
        creation_date=timezone.make_aware(datetime.datetime(2025, 3, 1)),
        source_device=device,
    )
    factories["history.Listening"](
        user=user,
        creation_date=timezone.make_aware(datetime.datetime(2024, 3, 1)),
        source_device=device,
    )
    factories["history.Listening"](
        user=user,
        creation_date=timezone.make_aware(datetime.datetime(2025, 3, 1)),
        source_device=None,
    )

    url = reverse("api:v1:history:listenings-list")
    response = logged_in_api_client.get(
        url,
        {
            "year": 2025,
            "source_device": str(device.uuid),
        },
    )

    assert response.status_code == 200
    assert response.data["count"] == 1
    assert response.data["results"][0]["id"] == in_range.pk
