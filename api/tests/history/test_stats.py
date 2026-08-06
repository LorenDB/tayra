import datetime

from django.urls import reverse
from django.utils import timezone


def _stats_url(**params):
    url = reverse("api:v1:history:listenings-stats")
    if not params:
        return url
    query = "&".join(f"{k}={v}" for k, v in params.items())
    return f"{url}?{query}"


def _dt(year, month=6, day=15, hour=12):
    return timezone.make_aware(datetime.datetime(year, month, day, hour, 0, 0))


def test_stats_requires_authentication(factories, api_client, preferences):
    preferences["common__api_authentication_required"] = False
    response = api_client.get(_stats_url(year=2025))
    assert response.status_code == 401


def test_stats_empty_year(factories, logged_in_api_client):
    response = logged_in_api_client.get(_stats_url(year=2025))
    assert response.status_code == 200
    data = response.data
    assert data["year"] == 2025
    assert data["total_listens"] == 0
    assert data["total_seconds"] == 0
    assert data["listens_with_duration"] == 0
    assert data["estimated_seconds"] == 0
    assert data["unique_tracks"] == 0
    assert data["unique_artists"] == 0
    assert data["unique_albums"] == 0
    assert data["top_tracks"] == []
    assert data["top_artists"] == []
    assert data["top_albums"] == []
    assert len(data["monthly"]) == 12
    assert all(m["count"] == 0 and m["total_seconds"] == 0 for m in data["monthly"])
    assert data["by_device"] == []


def test_stats_monthly_aggregates_many_distinct_timestamps(
    factories, logged_in_api_client
):
    """
    Many listens in one month with unique creation_dates must sum correctly.

    Listening.Meta.ordering includes creation_date; without clearing that
    order before values().annotate(), Django folds creation_date into
    GROUP BY and each month collapses to count=1.
    """
    user = logged_in_api_client.user
    year = 2025
    track = factories["music.Track"]()
    device = factories["client_data.ClientDevice"](user=user)
    for day in range(1, 11):
        factories["history.Listening"](
            user=user,
            track=track,
            duration_seconds=30,
            source_device=device,
            creation_date=_dt(year, 3, day, hour=day),
        )

    response = logged_in_api_client.get(_stats_url(year=year))
    assert response.status_code == 200
    monthly = {m["month"]: m for m in response.data["monthly"]}
    assert monthly[3]["count"] == 10
    assert monthly[3]["total_seconds"] == 300
    assert response.data["total_listens"] == 10


def test_stats_mixed_null_and_non_null_durations(factories, logged_in_api_client):
    """total_seconds ignores null durations; estimated_seconds uses track length."""
    user = logged_in_api_client.user
    year = 2025
    track_a = factories["music.Track"](title="Song A")
    track_b = factories["music.Track"](title="Song B")
    track_c = factories["music.Track"](title="Song C")
    # Upload durations used only for estimated_seconds fallback
    factories["music.Upload"](track=track_a, duration=200, import_status="finished")
    factories["music.Upload"](track=track_b, duration=300, import_status="finished")
    factories["music.Upload"](track=track_c, duration=400, import_status="finished")

    device = factories["client_data.ClientDevice"](user=user, name="Pixel")

    # Rich listens with actual duration
    factories["history.Listening"](
        user=user,
        track=track_a,
        duration_seconds=100,
        source_device=device,
        creation_date=_dt(year, 1, 10),
    )
    factories["history.Listening"](
        user=user,
        track=track_a,
        duration_seconds=50,
        source_device=device,
        creation_date=_dt(year, 1, 11),
    )
    # Stock row: null duration → contributes 0 to total_seconds, track len to estimated
    factories["history.Listening"](
        user=user,
        track=track_b,
        duration_seconds=None,
        source_device=None,
        creation_date=_dt(year, 3, 5),
    )
    # Another stock row on track_c
    factories["history.Listening"](
        user=user,
        track=track_c,
        duration_seconds=None,
        creation_date=_dt(year, 3, 6),
    )
    # Listen outside the year must not count
    factories["history.Listening"](
        user=user,
        track=track_a,
        duration_seconds=999,
        creation_date=_dt(2024, 12, 31),
    )
    # Other user's listen must not count
    factories["history.Listening"](
        user=factories["users.User"](),
        track=track_a,
        duration_seconds=888,
        creation_date=_dt(year, 6, 1),
    )

    response = logged_in_api_client.get(_stats_url(year=year, limit=10))
    assert response.status_code == 200
    data = response.data

    assert data["year"] == year
    # Stock thin rows (null duration/device/session) are ignored — only 2 rich listens.
    assert data["total_listens"] == 2
    # 100 + 50
    assert data["total_seconds"] == 150
    assert data["listens_with_duration"] == 2
    # All rich rows have duration → estimated == total_seconds
    assert data["estimated_seconds"] == 150
    assert data["unique_tracks"] == 1
    assert data["unique_artists"] == 1
    assert data["unique_albums"] == 1

    # Top tracks: only track_a (rich)
    assert len(data["top_tracks"]) == 1
    assert data["top_tracks"][0]["track_id"] == track_a.pk
    assert data["top_tracks"][0]["title"] == "Song A"
    assert data["top_tracks"][0]["count"] == 2
    assert data["top_tracks"][0]["total_seconds"] == 150
    assert (
        data["top_tracks"][0]["artist_name"]
        == track_a.artist_credit.first().artist.name
    )

    track_ids = {t["track_id"] for t in data["top_tracks"]}
    assert track_ids == {track_a.pk}

    # Monthly: January only (2 rich listens); March stock rows ignored
    monthly = {m["month"]: m for m in data["monthly"]}
    assert monthly[1]["count"] == 2
    assert monthly[1]["total_seconds"] == 150
    assert monthly[3]["count"] == 0
    assert monthly[3]["total_seconds"] == 0
    assert monthly[6]["count"] == 0

    # by_device: only the named device (stock null-device group excluded)
    by_device = data["by_device"]
    assert len(by_device) == 1
    device_row = by_device[0]
    assert device_row["device_uuid"] == str(device.uuid)
    assert device_row["device_name"] == "Pixel"
    assert device_row["count"] == 2
    assert device_row["total_seconds"] == 150

    assert len(data["top_artists"]) == 1
    assert len(data["top_albums"]) == 1


def test_stats_estimated_prefers_finished_upload_duration(
    factories, logged_in_api_client
):
    """Finished upload wins over an earlier pending upload with different duration."""
    user = logged_in_api_client.user
    year = 2025
    track = factories["music.Track"]()
    # Earlier pending upload must not win when a finished one exists.
    factories["music.Upload"](track=track, duration=111, import_status="pending")
    factories["music.Upload"](track=track, duration=222, import_status="finished")
    # Rich row with null duration but device set (counts as rich; estimated uses upload).
    device = factories["client_data.ClientDevice"](user=user)
    factories["history.Listening"](
        user=user,
        track=track,
        duration_seconds=None,
        source_device=device,
        creation_date=_dt(year, 5, 1),
    )

    response = logged_in_api_client.get(_stats_url(year=year))
    assert response.status_code == 200
    assert response.data["total_listens"] == 1
    assert response.data["total_seconds"] == 0
    assert response.data["estimated_seconds"] == 222


def test_stats_ignores_stock_thin_listenings(factories, logged_in_api_client):
    """Pure stock scrobbles never appear in year-review aggregates."""
    user = logged_in_api_client.user
    year = 2025
    track = factories["music.Track"]()
    factories["music.Upload"](track=track, duration=500, import_status="finished")
    factories["history.Listening"](
        user=user,
        track=track,
        duration_seconds=None,
        source_device=None,
        client_session_id=None,
        creation_date=_dt(year, 7, 1),
    )

    response = logged_in_api_client.get(_stats_url(year=year))
    assert response.status_code == 200
    assert response.data["total_listens"] == 0
    assert response.data["total_seconds"] == 0
    assert response.data["estimated_seconds"] == 0
    assert response.data["top_tracks"] == []


def test_stats_limit_caps_top_n(factories, logged_in_api_client):
    user = logged_in_api_client.user
    year = 2025
    tracks = [factories["music.Track"]() for _ in range(5)]
    for i, track in enumerate(tracks):
        # Distinct counts so ranking is stable: track 0 most listened
        for _ in range(5 - i):
            factories["history.Listening"](
                user=user,
                track=track,
                duration_seconds=10,
                creation_date=_dt(year, 7, 1 + i),
            )

    response = logged_in_api_client.get(_stats_url(year=year, limit=2))
    assert response.status_code == 200
    assert len(response.data["top_tracks"]) == 2
    assert response.data["top_tracks"][0]["track_id"] == tracks[0].pk
    assert response.data["top_tracks"][0]["count"] == 5
    assert response.data["top_tracks"][1]["track_id"] == tracks[1].pk
    assert response.data["top_tracks"][1]["count"] == 4
    assert len(response.data["top_artists"]) == 2
    assert len(response.data["top_albums"]) == 2


def test_stats_default_limit_is_ten(factories, logged_in_api_client):
    user = logged_in_api_client.user
    year = 2025
    tracks = [factories["music.Track"]() for _ in range(11)]
    for i, track in enumerate(tracks):
        factories["history.Listening"](
            user=user,
            track=track,
            duration_seconds=10,
            creation_date=_dt(year, 8, 1),
        )
        # Extra listens on lower-index tracks so ranking is deterministic
        for _ in range(11 - i):
            factories["history.Listening"](
                user=user,
                track=track,
                duration_seconds=5,
                creation_date=_dt(year, 8, 2),
            )

    response = logged_in_api_client.get(_stats_url(year=year))
    assert response.status_code == 200
    assert len(response.data["top_tracks"]) == 10
    assert len(response.data["top_artists"]) == 10
    assert len(response.data["top_albums"]) == 10
    assert response.data["top_tracks"][0]["track_id"] == tracks[0].pk


def test_stats_limit_default_and_max(factories, logged_in_api_client):
    response = logged_in_api_client.get(_stats_url(year=2025, limit=51))
    assert response.status_code == 400
    assert response.data["limit"][0]["code"] == "invalid"

    response = logged_in_api_client.get(_stats_url(year=2025, limit=0))
    assert response.status_code == 400

    response = logged_in_api_client.get(_stats_url(year=2025, limit="nope"))
    assert response.status_code == 400

    # Valid max
    response = logged_in_api_client.get(_stats_url(year=2025, limit=50))
    assert response.status_code == 200


def test_stats_invalid_year(factories, logged_in_api_client):
    response = logged_in_api_client.get(_stats_url(year="abc"))
    assert response.status_code == 400
    assert response.data["year"][0]["code"] == "invalid"

    response = logged_in_api_client.get(_stats_url(year=1800))
    assert response.status_code == 400

    response = logged_in_api_client.get(_stats_url(year=2101))
    assert response.status_code == 400
    assert response.data["year"][0]["code"] == "invalid"

    # Inclusive bounds succeed
    response = logged_in_api_client.get(_stats_url(year=1970))
    assert response.status_code == 200
    assert response.data["year"] == 1970

    response = logged_in_api_client.get(_stats_url(year=2100))
    assert response.status_code == 200
    assert response.data["year"] == 2100


def test_stats_combined_param_errors(factories, logged_in_api_client):
    response = logged_in_api_client.get(_stats_url(year="abc", limit=99))
    assert response.status_code == 400
    assert response.data["year"][0]["code"] == "invalid"
    assert response.data["limit"][0]["code"] == "invalid"


def test_stats_owner_only_ignores_other_users(factories, logged_in_api_client):
    user = logged_in_api_client.user
    other = factories["users.User"]()
    track = factories["music.Track"]()
    year = 2025

    factories["history.Listening"](
        user=user,
        track=track,
        duration_seconds=30,
        creation_date=_dt(year, 2, 1),
    )
    factories["history.Listening"](
        user=other,
        track=track,
        duration_seconds=500,
        creation_date=_dt(year, 2, 1),
    )

    response = logged_in_api_client.get(_stats_url(year=year))
    assert response.status_code == 200
    assert response.data["total_listens"] == 1
    assert response.data["total_seconds"] == 30


def test_stats_defaults_year_to_current(factories, logged_in_api_client):
    current_year = timezone.now().year
    response = logged_in_api_client.get(_stats_url())
    assert response.status_code == 200
    assert response.data["year"] == current_year


def test_stats_other_authenticated_user_cannot_see_target(
    factories, logged_in_api_client
):
    """Stats always use request.user; no username impersonation."""
    owner = factories["users.User"]()
    track = factories["music.Track"]()
    year = 2025
    factories["history.Listening"](
        user=owner,
        track=track,
        duration_seconds=100,
        creation_date=_dt(year, 4, 1),
    )

    # Even if a username query param is passed, only self is aggregated.
    response = logged_in_api_client.get(
        _stats_url(year=year) + f"&username={owner.username}"
    )
    assert response.status_code == 200
    assert response.data["total_listens"] == 0


def test_oauth_read_listenings_allows_stats(factories, api_client):
    user = factories["users.User"]()
    scope = "read:listenings"
    token = factories["users.AccessToken"](
        user=user,
        scope=scope,
        application__scope=scope,
    )
    response = api_client.get(
        _stats_url(year=2025),
        HTTP_AUTHORIZATION=f"Bearer {token.token}",
    )
    assert response.status_code == 200
    assert response.data["total_listens"] == 0


def test_oauth_write_only_listenings_denies_stats(factories, api_client):
    user = factories["users.User"]()
    scope = "write:listenings"
    token = factories["users.AccessToken"](
        user=user,
        scope=scope,
        application__scope=scope,
    )
    response = api_client.get(
        _stats_url(year=2025),
        HTTP_AUTHORIZATION=f"Bearer {token.token}",
    )
    assert response.status_code == 403


def test_oauth_unrelated_scope_denies_stats(factories, api_client):
    user = factories["users.User"]()
    scope = "read:profile"
    token = factories["users.AccessToken"](
        user=user,
        scope=scope,
        application__scope=scope,
    )
    response = api_client.get(
        _stats_url(year=2025),
        HTTP_AUTHORIZATION=f"Bearer {token.token}",
    )
    assert response.status_code == 403
