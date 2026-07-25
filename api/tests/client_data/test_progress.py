import datetime
import uuid

from django.urls import reverse
from django.utils import timezone

from funkwhale_api.client_data import models


def _list_url():
    return reverse("api:v1:client_data:playback-progress-list")


def _detail_url(track_id):
    return reverse(
        "api:v1:client_data:playback-progress-detail",
        kwargs={"track_id": track_id},
    )


def _bulk_url():
    return reverse("api:v1:client_data:playback-progress-bulk")


def test_put_creates_progress(factories, logged_in_api_client):
    track = factories["music.Track"]()
    payload = {
        "position_ms": 125000,
        "duration_ms": 3600000,
        "completed": False,
    }

    response = logged_in_api_client.put(
        _detail_url(track.pk), payload, format="json"
    )

    assert response.status_code == 201
    assert response.data["track"] == track.pk
    assert response.data["position_ms"] == 125000
    assert response.data["duration_ms"] == 3600000
    assert response.data["completed"] is False

    progress = models.PlaybackProgress.objects.get()
    assert progress.user == logged_in_api_client.user
    assert progress.track_id == track.pk
    assert progress.position_ms == 125000


def test_put_updates_existing(factories, logged_in_api_client):
    track = factories["music.Track"]()
    factories["client_data.PlaybackProgress"](
        user=logged_in_api_client.user,
        track=track,
        position_ms=1000,
        duration_ms=10000,
    )

    response = logged_in_api_client.put(
        _detail_url(track.pk),
        {"position_ms": 5000, "duration_ms": 10000},
        format="json",
    )

    assert response.status_code == 200
    assert response.data["position_ms"] == 5000
    assert models.PlaybackProgress.objects.count() == 1


def test_completed_auto_at_90_percent(factories, logged_in_api_client):
    track = factories["music.Track"]()
    # 90% of 10000 = 9000
    response = logged_in_api_client.put(
        _detail_url(track.pk),
        {"position_ms": 9000, "duration_ms": 10000, "completed": False},
        format="json",
    )

    assert response.status_code == 201
    assert response.data["completed"] is True


def test_completed_honors_client_flag(factories, logged_in_api_client):
    track = factories["music.Track"]()
    response = logged_in_api_client.put(
        _detail_url(track.pk),
        {"position_ms": 100, "duration_ms": 10000, "completed": True},
        format="json",
    )

    assert response.status_code == 201
    assert response.data["completed"] is True


def test_completed_sticky_when_omitted_on_position_only_put(
    factories, logged_in_api_client
):
    """Mark-as-played at low position must not clear on later position-only PUTs."""
    track = factories["music.Track"]()
    response = logged_in_api_client.put(
        _detail_url(track.pk),
        {"position_ms": 100, "duration_ms": 10000, "completed": True},
        format="json",
    )
    assert response.status_code == 201
    assert response.data["completed"] is True

    response = logged_in_api_client.put(
        _detail_url(track.pk),
        {"position_ms": 200},
        format="json",
    )
    assert response.status_code == 200
    assert response.data["completed"] is True
    assert response.data["position_ms"] == 200
    assert response.data["duration_ms"] == 10000  # not wiped


def test_completed_explicit_false_clears_when_below_threshold(
    factories, logged_in_api_client
):
    track = factories["music.Track"]()
    factories["client_data.PlaybackProgress"](
        user=logged_in_api_client.user,
        track=track,
        position_ms=100,
        duration_ms=10000,
        completed=True,
    )
    response = logged_in_api_client.put(
        _detail_url(track.pk),
        {"position_ms": 100, "duration_ms": 10000, "completed": False},
        format="json",
    )
    assert response.status_code == 200
    assert response.data["completed"] is False


def test_put_rejects_far_future_updated_at(factories, logged_in_api_client):
    track = factories["music.Track"]()
    far_future = (
        timezone.now() + datetime.timedelta(hours=1)
    ).isoformat().replace("+00:00", "Z")

    response = logged_in_api_client.put(
        _detail_url(track.pk),
        {"position_ms": 100, "updated_at": far_future},
        format="json",
    )

    assert response.status_code == 400
    assert response.data["updated_at"][0]["code"] == "updated_at_in_future"


def test_put_conflict_when_client_updated_at_older(factories, logged_in_api_client):
    track = factories["music.Track"]()
    server_time = timezone.now()
    factories["client_data.PlaybackProgress"](
        user=logged_in_api_client.user,
        track=track,
        position_ms=5000,
        duration_ms=10000,
        updated_at=server_time,
    )
    older = (server_time - datetime.timedelta(hours=1)).isoformat().replace(
        "+00:00", "Z"
    )

    response = logged_in_api_client.put(
        _detail_url(track.pk),
        {
            "position_ms": 100,
            "duration_ms": 10000,
            "updated_at": older,
        },
        format="json",
    )

    assert response.status_code == 409
    assert response.data["code"] == "progress_conflict"
    assert response.data["progress"]["position_ms"] == 5000

    progress = models.PlaybackProgress.objects.get()
    assert progress.position_ms == 5000


def test_put_accepts_newer_updated_at(factories, logged_in_api_client):
    track = factories["music.Track"]()
    older = timezone.now() - datetime.timedelta(hours=1)
    factories["client_data.PlaybackProgress"](
        user=logged_in_api_client.user,
        track=track,
        position_ms=1000,
        updated_at=older,
    )
    newer = timezone.now().isoformat().replace("+00:00", "Z")

    response = logged_in_api_client.put(
        _detail_url(track.pk),
        {"position_ms": 2000, "updated_at": newer},
        format="json",
    )

    assert response.status_code == 200
    assert response.data["position_ms"] == 2000


def test_put_unknown_track_returns_track_not_found(factories, logged_in_api_client):
    response = logged_in_api_client.put(
        _detail_url(999999),
        {"position_ms": 100},
        format="json",
    )

    assert response.status_code == 400
    assert response.data["track"][0]["code"] == "track_not_found"


def test_put_with_source_device(factories, logged_in_api_client):
    track = factories["music.Track"]()
    device = factories["client_data.ClientDevice"](user=logged_in_api_client.user)

    response = logged_in_api_client.put(
        _detail_url(track.pk),
        {
            "position_ms": 100,
            "source_device": str(device.uuid),
            "channel_uuid": str(uuid.uuid4()),
        },
        format="json",
    )

    assert response.status_code == 201
    assert response.data["source_device"] == str(device.uuid)
    assert response.data["channel_uuid"] is not None


def test_put_unregistered_device(factories, logged_in_api_client):
    track = factories["music.Track"]()
    response = logged_in_api_client.put(
        _detail_url(track.pk),
        {"position_ms": 100, "source_device": str(uuid.uuid4())},
        format="json",
    )

    assert response.status_code == 400
    assert response.data["source_device"][0]["code"] == "device_not_registered"


def test_put_inactive_device(factories, logged_in_api_client):
    track = factories["music.Track"]()
    device = factories["client_data.ClientDevice"](
        user=logged_in_api_client.user, is_active=False
    )
    response = logged_in_api_client.put(
        _detail_url(track.pk),
        {"position_ms": 100, "source_device": str(device.uuid)},
        format="json",
    )

    assert response.status_code == 400
    assert response.data["source_device"][0]["code"] == "device_inactive"


def test_list_own_only(factories, logged_in_api_client):
    mine = factories["client_data.PlaybackProgress"](
        user=logged_in_api_client.user
    )
    factories["client_data.PlaybackProgress"]()  # other user

    response = logged_in_api_client.get(_list_url())

    assert response.status_code == 200
    assert response.data["count"] == 1
    assert response.data["results"][0]["track"] == mine.track_id


def test_list_filter_channel_uuid(factories, logged_in_api_client):
    channel = uuid.uuid4()
    match = factories["client_data.PlaybackProgress"](
        user=logged_in_api_client.user, channel_uuid=channel
    )
    factories["client_data.PlaybackProgress"](
        user=logged_in_api_client.user, channel_uuid=uuid.uuid4()
    )

    response = logged_in_api_client.get(
        _list_url(), {"channel_uuid": str(channel)}
    )

    assert response.status_code == 200
    assert response.data["count"] == 1
    assert response.data["results"][0]["track"] == match.track_id


def test_list_filter_completed(factories, logged_in_api_client):
    factories["client_data.PlaybackProgress"](
        user=logged_in_api_client.user, completed=True
    )
    factories["client_data.PlaybackProgress"](
        user=logged_in_api_client.user, completed=False
    )

    response = logged_in_api_client.get(_list_url(), {"completed": "true"})

    assert response.status_code == 200
    assert response.data["count"] == 1
    assert response.data["results"][0]["completed"] is True


def test_list_filter_updated_at_range(factories, logged_in_api_client):
    older_ts = timezone.now() - datetime.timedelta(days=2)
    newer_ts = timezone.now() - datetime.timedelta(hours=1)
    old_row = factories["client_data.PlaybackProgress"](
        user=logged_in_api_client.user, position_ms=1, updated_at=older_ts
    )
    new_row = factories["client_data.PlaybackProgress"](
        user=logged_in_api_client.user, position_ms=2, updated_at=newer_ts
    )

    after = (older_ts + datetime.timedelta(hours=1)).isoformat().replace(
        "+00:00", "Z"
    )
    response = logged_in_api_client.get(
        _list_url(), {"updated_at_after": after}
    )

    assert response.status_code == 200
    assert response.data["count"] == 1
    assert response.data["results"][0]["track"] == new_row.track_id
    assert response.data["results"][0]["track"] != old_row.track_id


def test_retrieve_by_track_id(factories, logged_in_api_client):
    progress = factories["client_data.PlaybackProgress"](
        user=logged_in_api_client.user, position_ms=42
    )

    response = logged_in_api_client.get(_detail_url(progress.track_id))

    assert response.status_code == 200
    assert response.data["position_ms"] == 42
    assert response.data["track"] == progress.track_id


def test_delete_progress(factories, logged_in_api_client):
    progress = factories["client_data.PlaybackProgress"](
        user=logged_in_api_client.user
    )

    response = logged_in_api_client.delete(_detail_url(progress.track_id))

    assert response.status_code == 204
    assert models.PlaybackProgress.objects.count() == 0


def test_cannot_access_other_users_progress(factories, logged_in_api_client):
    other = factories["client_data.PlaybackProgress"](position_ms=777)
    original_position = other.position_ms

    response = logged_in_api_client.get(_detail_url(other.track_id))
    assert response.status_code == 404

    response = logged_in_api_client.put(
        _detail_url(other.track_id),
        {"position_ms": 1},
        format="json",
    )
    # Upsert creates a new row for the current user on that track (shared track OK)
    assert response.status_code == 201
    assert models.PlaybackProgress.objects.filter(
        user=logged_in_api_client.user, track_id=other.track_id
    ).exists()
    # Other user's row untouched
    other.refresh_from_db()
    assert other.position_ms == original_position

    response = logged_in_api_client.delete(_detail_url(other.track_id))
    # Deletes own row created above
    assert response.status_code == 204


def test_anonymous_denied(db, api_client, preferences):
    preferences["common__api_authentication_required"] = False
    response = api_client.get(_list_url())
    assert response.status_code in (401, 403)


def test_oauth_requires_client_data_scope(factories, api_client):
    user = factories["users.User"]()
    scope = "read:listenings write:listenings"
    token = factories["users.AccessToken"](
        user=user, scope=scope, application__scope=scope
    )

    response = api_client.get(
        _list_url(), HTTP_AUTHORIZATION=f"Bearer {token.token}"
    )
    assert response.status_code == 403


def test_oauth_with_client_data_scope(factories, api_client):
    user = factories["users.User"]()
    scope = "read:client_data write:client_data"
    token = factories["users.AccessToken"](
        user=user, scope=scope, application__scope=scope
    )
    track = factories["music.Track"]()

    response = api_client.put(
        _detail_url(track.pk),
        {"position_ms": 50},
        format="json",
        HTTP_AUTHORIZATION=f"Bearer {token.token}",
    )
    assert response.status_code == 201
    assert models.PlaybackProgress.objects.filter(user=user, track=track).exists()


def test_bulk_creates_and_updates_lww(factories, logged_in_api_client):
    track_new = factories["music.Track"]()
    track_old = factories["music.Track"]()
    track_skip = factories["music.Track"]()
    now = timezone.now()
    older = now - datetime.timedelta(hours=2)
    newer = now + datetime.timedelta(minutes=1)

    factories["client_data.PlaybackProgress"](
        user=logged_in_api_client.user,
        track=track_old,
        position_ms=100,
        updated_at=older,
    )
    factories["client_data.PlaybackProgress"](
        user=logged_in_api_client.user,
        track=track_skip,
        position_ms=999,
        updated_at=now,
    )

    payload = {
        "items": [
            {
                "track": track_new.pk,
                "position_ms": 10,
                "duration_ms": 1000,
                "updated_at": now.isoformat().replace("+00:00", "Z"),
            },
            {
                "track": track_old.pk,
                "position_ms": 500,
                "updated_at": newer.isoformat().replace("+00:00", "Z"),
            },
            {
                "track": track_skip.pk,
                "position_ms": 1,
                "updated_at": older.isoformat().replace("+00:00", "Z"),
            },
            {
                "track": 999999,
                "position_ms": 1,
            },
        ]
    }

    response = logged_in_api_client.post(_bulk_url(), payload, format="json")

    assert response.status_code == 200
    assert response.data["created"] == 1
    assert response.data["updated"] == 1
    assert response.data["skipped"] == 1
    assert len(response.data["errors"]) == 1
    assert response.data["errors"][0]["code"] == "track_not_found"
    assert response.data["errors"][0]["index"] == 3

    assert models.PlaybackProgress.objects.get(track=track_new).position_ms == 10
    assert models.PlaybackProgress.objects.get(track=track_old).position_ms == 500
    assert models.PlaybackProgress.objects.get(track=track_skip).position_ms == 999


def test_bulk_batch_too_large(factories, logged_in_api_client):
    track = factories["music.Track"]()
    items = [{"track": track.pk, "position_ms": 0} for _ in range(501)]

    response = logged_in_api_client.post(
        _bulk_url(), {"items": items}, format="json"
    )

    assert response.status_code == 400
    assert response.data["items"][0]["code"] == "batch_too_large"


def test_bulk_empty_items(factories, logged_in_api_client):
    response = logged_in_api_client.post(
        _bulk_url(), {"items": []}, format="json"
    )
    assert response.status_code == 400


def test_bulk_with_device(factories, logged_in_api_client):
    track = factories["music.Track"]()
    device = factories["client_data.ClientDevice"](user=logged_in_api_client.user)

    response = logged_in_api_client.post(
        _bulk_url(),
        {
            "items": [
                {
                    "track": track.pk,
                    "position_ms": 100,
                    "source_device": str(device.uuid),
                }
            ]
        },
        format="json",
    )

    assert response.status_code == 200
    assert response.data["created"] == 1
    progress = models.PlaybackProgress.objects.get()
    assert progress.source_device_id == device.pk


def test_bulk_omitted_optional_fields_do_not_wipe(factories, logged_in_api_client):
    track = factories["music.Track"]()
    channel = uuid.uuid4()
    older = timezone.now() - datetime.timedelta(hours=1)
    factories["client_data.PlaybackProgress"](
        user=logged_in_api_client.user,
        track=track,
        position_ms=100,
        duration_ms=5000,
        channel_uuid=channel,
        completed=True,
        updated_at=older,
    )
    newer = timezone.now().isoformat().replace("+00:00", "Z")

    response = logged_in_api_client.post(
        _bulk_url(),
        {
            "items": [
                {
                    "track": track.pk,
                    "position_ms": 250,
                    "updated_at": newer,
                    # duration_ms, channel_uuid, completed, source_device omitted
                }
            ]
        },
        format="json",
    )

    assert response.status_code == 200
    assert response.data["updated"] == 1
    progress = models.PlaybackProgress.objects.get(track=track)
    assert progress.position_ms == 250
    assert progress.duration_ms == 5000
    assert progress.channel_uuid == channel
    assert progress.completed is True


def test_resolve_completed_threshold_unit():
    assert models.PlaybackProgress.resolve_completed(8999, 10000) is False
    assert models.PlaybackProgress.resolve_completed(9000, 10000) is True
    assert models.PlaybackProgress.resolve_completed(0, None) is False
    assert models.PlaybackProgress.resolve_completed(0, None, client_completed=True) is True
    # Odd duration integer boundary: 90% of 7 = 6.3 → need position 7 for >= 90%
    # position * 10 >= duration * 9 → position * 10 >= 63 → position >= 7
    assert models.PlaybackProgress.resolve_completed(6, 7) is False
    assert models.PlaybackProgress.resolve_completed(7, 7) is True
