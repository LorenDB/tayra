import concurrent.futures
import datetime
import uuid

import pytest
from django.db import connection, connections
from django.urls import reverse
from django.utils import timezone
from rest_framework.test import APIClient

from funkwhale_api.history import models


def _list_url():
    return reverse("api:v1:history:listenings-list")


def _detail_url(pk):
    return reverse("api:v1:history:listenings-detail", kwargs={"pk": pk})


def _rich_keys_absent(data):
    assert "duration_seconds" not in data
    assert "source_device" not in data
    assert "client_session_id" not in data
    assert "updated_at" not in data


def test_thin_stock_create_still_works(
    factories, logged_in_api_client, activity_muted, mocker
):
    track = factories["music.Track"]()
    plugin_hook = mocker.patch("config.plugins.trigger_hook")

    response = logged_in_api_client.post(
        _list_url(), {"track": track.pk}, format="json"
    )

    assert response.status_code == 201
    listening = models.Listening.objects.get()
    assert listening.track_id == track.pk
    assert listening.user == logged_in_api_client.user
    assert listening.duration_seconds is None
    assert listening.source_device_id is None
    assert listening.client_session_id is None
    assert response.data["user"] == logged_in_api_client.user.pk
    activity_muted.assert_called_once_with(listening)
    plugin_hook.assert_called_once()


def test_rich_create_with_device_and_session(
    factories, logged_in_api_client, activity_muted, mocker
):
    track = factories["music.Track"]()
    device = factories["client_data.ClientDevice"](user=logged_in_api_client.user)
    session_id = uuid.uuid4()
    plugin_hook = mocker.patch("config.plugins.trigger_hook")

    payload = {
        "track": track.pk,
        "duration_seconds": 42,
        "source_device": str(device.uuid),
        "client_session_id": str(session_id),
    }
    response = logged_in_api_client.post(_list_url(), payload, format="json")

    assert response.status_code == 201
    assert response.data["duration_seconds"] == 42
    assert response.data["source_device"] == str(device.uuid)
    assert response.data["client_session_id"] == str(session_id)
    assert response.data["user"] == logged_in_api_client.user.pk

    listening = models.Listening.objects.get()
    assert listening.duration_seconds == 42
    assert listening.source_device_id == device.pk
    assert listening.client_session_id == session_id
    activity_muted.assert_called_once_with(listening)
    plugin_hook.assert_called_once()


def test_idempotent_session_repost_returns_200_max_duration_no_plugins(
    factories, logged_in_api_client, activity_muted, mocker
):
    track = factories["music.Track"]()
    device = factories["client_data.ClientDevice"](user=logged_in_api_client.user)
    session_id = uuid.uuid4()
    plugin_hook = mocker.patch("config.plugins.trigger_hook")

    payload = {
        "track": track.pk,
        "duration_seconds": 10,
        "source_device": str(device.uuid),
        "client_session_id": str(session_id),
    }
    first = logged_in_api_client.post(_list_url(), payload, format="json")
    assert first.status_code == 201
    assert models.Listening.objects.count() == 1
    activity_muted.assert_called_once()
    plugin_hook.assert_called_once()

    activity_muted.reset_mock()
    plugin_hook.reset_mock()

    payload["duration_seconds"] = 90
    second = logged_in_api_client.post(_list_url(), payload, format="json")

    assert second.status_code == 200
    assert second.data["duration_seconds"] == 90
    assert models.Listening.objects.count() == 1
    listening = models.Listening.objects.get()
    assert listening.duration_seconds == 90
    activity_muted.assert_not_called()
    plugin_hook.assert_not_called()


def test_idempotent_session_repost_does_not_decrease_duration(
    factories, logged_in_api_client, activity_muted, mocker
):
    track = factories["music.Track"]()
    session_id = uuid.uuid4()
    mocker.patch("config.plugins.trigger_hook")

    payload = {
        "track": track.pk,
        "duration_seconds": 100,
        "client_session_id": str(session_id),
    }
    assert (
        logged_in_api_client.post(_list_url(), payload, format="json").status_code
        == 201
    )

    payload["duration_seconds"] = 20
    response = logged_in_api_client.post(_list_url(), payload, format="json")
    assert response.status_code == 200
    assert response.data["duration_seconds"] == 100
    assert models.Listening.objects.get().duration_seconds == 100


def test_session_repost_accepts_original_creation_date_after_window(
    factories, logged_in_api_client, activity_muted, mocker
):
    """Crash recovery: re-POST with original creation_date older than 5 min still merges."""
    track = factories["music.Track"]()
    session_id = uuid.uuid4()
    mocker.patch("config.plugins.trigger_hook")

    payload = {
        "track": track.pk,
        "duration_seconds": 15,
        "client_session_id": str(session_id),
    }
    assert (
        logged_in_api_client.post(_list_url(), payload, format="json").status_code
        == 201
    )

    old = timezone.now() - datetime.timedelta(minutes=30)
    payload["duration_seconds"] = 120
    payload["creation_date"] = old.isoformat().replace("+00:00", "Z")
    response = logged_in_api_client.post(_list_url(), payload, format="json")

    assert response.status_code == 200
    assert response.data["duration_seconds"] == 120
    assert models.Listening.objects.count() == 1
    assert models.Listening.objects.get().duration_seconds == 120


def test_create_null_source_device_ok(
    factories, logged_in_api_client, activity_muted, mocker
):
    track = factories["music.Track"]()
    mocker.patch("config.plugins.trigger_hook")

    response = logged_in_api_client.post(
        _list_url(),
        {
            "track": track.pk,
            "duration_seconds": 5,
            "source_device": None,
            "client_session_id": str(uuid.uuid4()),
        },
        format="json",
    )

    assert response.status_code == 201
    assert response.data["source_device"] is None
    assert models.Listening.objects.get().source_device_id is None


def test_device_not_registered(factories, logged_in_api_client):
    track = factories["music.Track"]()
    response = logged_in_api_client.post(
        _list_url(),
        {
            "track": track.pk,
            "source_device": str(uuid.uuid4()),
        },
        format="json",
    )

    assert response.status_code == 400
    assert response.data["source_device"][0]["code"] == "device_not_registered"
    assert models.Listening.objects.count() == 0


def test_device_inactive(factories, logged_in_api_client):
    track = factories["music.Track"]()
    device = factories["client_data.ClientDevice"](
        user=logged_in_api_client.user, is_active=False
    )
    response = logged_in_api_client.post(
        _list_url(),
        {
            "track": track.pk,
            "source_device": str(device.uuid),
        },
        format="json",
    )

    assert response.status_code == 400
    assert response.data["source_device"][0]["code"] == "device_inactive"
    assert models.Listening.objects.count() == 0


def test_device_belongs_to_other_user(factories, logged_in_api_client):
    track = factories["music.Track"]()
    other_device = factories["client_data.ClientDevice"]()
    response = logged_in_api_client.post(
        _list_url(),
        {
            "track": track.pk,
            "source_device": str(other_device.uuid),
        },
        format="json",
    )

    assert response.status_code == 400
    assert response.data["source_device"][0]["code"] == "device_not_registered"


def test_creation_date_too_old(factories, logged_in_api_client):
    track = factories["music.Track"]()
    old = timezone.now() - datetime.timedelta(minutes=10)
    response = logged_in_api_client.post(
        _list_url(),
        {
            "track": track.pk,
            "creation_date": old.isoformat().replace("+00:00", "Z"),
        },
        format="json",
    )

    assert response.status_code == 400
    assert response.data["creation_date"][0]["code"] == "creation_date_too_old"


def test_creation_date_too_old_with_new_session(factories, logged_in_api_client):
    track = factories["music.Track"]()
    old = timezone.now() - datetime.timedelta(minutes=10)
    response = logged_in_api_client.post(
        _list_url(),
        {
            "track": track.pk,
            "creation_date": old.isoformat().replace("+00:00", "Z"),
            "client_session_id": str(uuid.uuid4()),
        },
        format="json",
    )

    assert response.status_code == 400
    assert response.data["creation_date"][0]["code"] == "creation_date_too_old"
    assert models.Listening.objects.count() == 0


def test_creation_date_in_future(factories, logged_in_api_client):
    track = factories["music.Track"]()
    future = timezone.now() + datetime.timedelta(minutes=10)
    response = logged_in_api_client.post(
        _list_url(),
        {
            "track": track.pk,
            "creation_date": future.isoformat().replace("+00:00", "Z"),
        },
        format="json",
    )

    assert response.status_code == 400
    assert response.data["creation_date"][0]["code"] == "creation_date_in_future"


def test_owner_retrieve_includes_rich_fields(factories, logged_in_api_client):
    device = factories["client_data.ClientDevice"](user=logged_in_api_client.user)
    session_id = uuid.uuid4()
    listening = factories["history.Listening"](
        user=logged_in_api_client.user,
        duration_seconds=33,
        source_device=device,
        client_session_id=session_id,
    )

    response = logged_in_api_client.get(_detail_url(listening.pk))

    assert response.status_code == 200
    assert response.data["duration_seconds"] == 33
    assert response.data["source_device"] == str(device.uuid)
    assert response.data["client_session_id"] == str(session_id)
    assert "updated_at" in response.data


def test_owner_null_source_device_read_no_500(factories, logged_in_api_client):
    listening = factories["history.Listening"](
        user=logged_in_api_client.user,
        duration_seconds=1,
        source_device=None,
    )

    response = logged_in_api_client.get(_detail_url(listening.pk))

    assert response.status_code == 200
    assert response.data["source_device"] is None
    assert response.data["duration_seconds"] == 1


def test_non_owner_privacy_strip(factories, logged_in_api_client):
    owner = factories["users.User"](privacy_level="everyone")
    device = factories["client_data.ClientDevice"](user=owner)
    listening = factories["history.Listening"](
        user=owner,
        duration_seconds=99,
        source_device=device,
        client_session_id=uuid.uuid4(),
    )

    response = logged_in_api_client.get(_detail_url(listening.pk))

    assert response.status_code == 200
    assert response.data["id"] == listening.pk
    _rich_keys_absent(response.data)


def test_anonymous_privacy_strip(factories, api_client, preferences):
    preferences["common__api_authentication_required"] = False
    owner = factories["users.User"](privacy_level="everyone")
    device = factories["client_data.ClientDevice"](user=owner)
    listening = factories["history.Listening"](
        user=owner,
        duration_seconds=50,
        source_device=device,
        client_session_id=uuid.uuid4(),
    )

    response = api_client.get(_detail_url(listening.pk))

    assert response.status_code == 200
    _rich_keys_absent(response.data)


def test_non_owner_list_privacy_strip(factories, logged_in_api_client):
    owner = factories["users.User"](privacy_level="everyone")
    device = factories["client_data.ClientDevice"](user=owner)
    factories["history.Listening"](
        user=owner,
        duration_seconds=99,
        source_device=device,
        client_session_id=uuid.uuid4(),
    )

    response = logged_in_api_client.get(_list_url())

    assert response.status_code == 200
    assert response.data["count"] == 1
    _rich_keys_absent(response.data["results"][0])


def test_anonymous_list_privacy_strip(factories, api_client, preferences):
    preferences["common__api_authentication_required"] = False
    owner = factories["users.User"](privacy_level="everyone")
    device = factories["client_data.ClientDevice"](user=owner)
    factories["history.Listening"](
        user=owner,
        duration_seconds=50,
        source_device=device,
        client_session_id=uuid.uuid4(),
    )

    response = api_client.get(_list_url())

    assert response.status_code == 200
    assert response.data["count"] == 1
    _rich_keys_absent(response.data["results"][0])


def test_owner_list_includes_rich_fields(factories, logged_in_api_client):
    device = factories["client_data.ClientDevice"](user=logged_in_api_client.user)
    factories["history.Listening"](
        user=logged_in_api_client.user,
        duration_seconds=12,
        source_device=device,
        client_session_id=uuid.uuid4(),
    )

    response = logged_in_api_client.get(_list_url())

    assert response.status_code == 200
    assert response.data["count"] == 1
    row = response.data["results"][0]
    assert row["duration_seconds"] == 12
    assert row["source_device"] == str(device.uuid)
    assert "client_session_id" in row
    assert "updated_at" in row


@pytest.mark.parametrize(
    "seconds",
    [86401, -1],
)
def test_duration_seconds_bounds(factories, logged_in_api_client, seconds):
    track = factories["music.Track"]()
    response = logged_in_api_client.post(
        _list_url(),
        {"track": track.pk, "duration_seconds": seconds},
        format="json",
    )
    assert response.status_code == 400


@pytest.mark.django_db(transaction=True)
def test_concurrent_dual_post_same_session(factories, mocker):
    """
    Concurrent dual POST same client_session_id: no 500, exactly one row,
    plugins/activity at most once. Gated on PostgreSQL — SQLite serializes writers
    and does not reliably exercise the unique-constraint race.
    """
    if connection.vendor == "sqlite":
        pytest.skip(
            "SQLite cannot reliably exercise concurrent unique-constraint races; "
            "sequential re-POST covers the merge path. Run on PostgreSQL for this case."
        )

    user = factories["users.User"]()
    track = factories["music.Track"]()
    session_id = uuid.uuid4()
    plugin_hook = mocker.patch("config.plugins.trigger_hook")
    activity_send = mocker.patch("funkwhale_api.activity.record.send")

    def do_post(duration):
        connections.close_all()
        client = APIClient()
        client.force_authenticate(user=user)
        return client.post(
            _list_url(),
            {
                "track": track.pk,
                "duration_seconds": duration,
                "client_session_id": str(session_id),
            },
            format="json",
        )

    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        futures = [pool.submit(do_post, d) for d in (10, 50)]
        results = [f.result() for f in concurrent.futures.as_completed(futures)]

    assert all(r.status_code in (200, 201) for r in results)
    assert (
        models.Listening.objects.filter(
            user=user, client_session_id=session_id
        ).count()
        == 1
    )
    assert models.Listening.objects.get().duration_seconds == 50
    assert plugin_hook.call_count <= 1
    assert activity_send.call_count <= 1


# --- PATCH / duration update / by-session (PR 3) ---


def _by_session_url(client_session_id):
    return reverse(
        "api:v1:history:listenings-by-session",
        kwargs={"client_session_id": str(client_session_id)},
    )


def test_patch_duration_increases(factories, logged_in_api_client):
    listening = factories["history.Listening"](
        user=logged_in_api_client.user,
        duration_seconds=10,
    )

    response = logged_in_api_client.patch(
        _detail_url(listening.pk),
        {"duration_seconds": 180},
        format="json",
    )

    assert response.status_code == 200
    assert response.data["duration_seconds"] == 180
    listening.refresh_from_db()
    assert listening.duration_seconds == 180


def test_patch_duration_monotonic_max(factories, logged_in_api_client):
    listening = factories["history.Listening"](
        user=logged_in_api_client.user,
        duration_seconds=100,
    )

    response = logged_in_api_client.patch(
        _detail_url(listening.pk),
        {"duration_seconds": 20},
        format="json",
    )

    assert response.status_code == 200
    assert response.data["duration_seconds"] == 100
    listening.refresh_from_db()
    assert listening.duration_seconds == 100


def test_patch_duration_from_null(factories, logged_in_api_client):
    listening = factories["history.Listening"](
        user=logged_in_api_client.user,
        duration_seconds=None,
    )

    response = logged_in_api_client.patch(
        _detail_url(listening.pk),
        {"duration_seconds": 45},
        format="json",
    )

    assert response.status_code == 200
    assert response.data["duration_seconds"] == 45
    listening.refresh_from_db()
    assert listening.duration_seconds == 45


def test_patch_source_device(factories, logged_in_api_client):
    listening = factories["history.Listening"](
        user=logged_in_api_client.user,
        duration_seconds=5,
        source_device=None,
    )
    device = factories["client_data.ClientDevice"](user=logged_in_api_client.user)

    response = logged_in_api_client.patch(
        _detail_url(listening.pk),
        {"source_device": str(device.uuid), "duration_seconds": 30},
        format="json",
    )

    assert response.status_code == 200
    assert response.data["source_device"] == str(device.uuid)
    assert response.data["duration_seconds"] == 30
    listening.refresh_from_db()
    assert listening.source_device_id == device.pk
    assert listening.duration_seconds == 30


def test_patch_source_device_not_registered(factories, logged_in_api_client):
    listening = factories["history.Listening"](user=logged_in_api_client.user)

    response = logged_in_api_client.patch(
        _detail_url(listening.pk),
        {"source_device": str(uuid.uuid4())},
        format="json",
    )

    assert response.status_code == 400
    assert response.data["source_device"][0]["code"] == "device_not_registered"


def test_patch_non_owner_404(factories, logged_in_api_client):
    owner = factories["users.User"](privacy_level="everyone")
    listening = factories["history.Listening"](
        user=owner,
        duration_seconds=10,
    )

    response = logged_in_api_client.patch(
        _detail_url(listening.pk),
        {"duration_seconds": 99},
        format="json",
    )

    assert response.status_code == 404
    listening.refresh_from_db()
    assert listening.duration_seconds == 10


def test_patch_immutable_fields_ignored(factories, logged_in_api_client):
    track = factories["music.Track"]()
    other_track = factories["music.Track"]()
    session_id = uuid.uuid4()
    creation = timezone.now() - datetime.timedelta(minutes=1)
    listening = factories["history.Listening"](
        user=logged_in_api_client.user,
        track=track,
        duration_seconds=10,
        client_session_id=session_id,
        creation_date=creation,
    )

    response = logged_in_api_client.patch(
        _detail_url(listening.pk),
        {
            "duration_seconds": 50,
            "track": other_track.pk,
            "client_session_id": str(uuid.uuid4()),
            "creation_date": timezone.now().isoformat().replace("+00:00", "Z"),
            "user": factories["users.User"]().pk,
        },
        format="json",
    )

    assert response.status_code == 200
    listening.refresh_from_db()
    assert listening.duration_seconds == 50
    assert listening.track_id == track.pk
    assert listening.client_session_id == session_id
    assert listening.user_id == logged_in_api_client.user.pk
    # creation_date unchanged (within second precision)
    assert abs((listening.creation_date - creation).total_seconds()) < 1


def test_patch_duration_bounds(factories, logged_in_api_client):
    listening = factories["history.Listening"](user=logged_in_api_client.user)

    response = logged_in_api_client.patch(
        _detail_url(listening.pk),
        {"duration_seconds": 86401},
        format="json",
    )
    assert response.status_code == 400


def test_by_session_patch_duration(factories, logged_in_api_client):
    session_id = uuid.uuid4()
    listening = factories["history.Listening"](
        user=logged_in_api_client.user,
        duration_seconds=10,
        client_session_id=session_id,
    )

    response = logged_in_api_client.patch(
        _by_session_url(session_id),
        {"duration_seconds": 200},
        format="json",
    )

    assert response.status_code == 200
    assert response.data["duration_seconds"] == 200
    assert response.data["client_session_id"] == str(session_id)
    listening.refresh_from_db()
    assert listening.duration_seconds == 200


def test_by_session_patch_monotonic_and_device(factories, logged_in_api_client):
    session_id = uuid.uuid4()
    device = factories["client_data.ClientDevice"](user=logged_in_api_client.user)
    listening = factories["history.Listening"](
        user=logged_in_api_client.user,
        duration_seconds=80,
        client_session_id=session_id,
    )

    response = logged_in_api_client.patch(
        _by_session_url(session_id),
        {"duration_seconds": 40, "source_device": str(device.uuid)},
        format="json",
    )

    assert response.status_code == 200
    assert response.data["duration_seconds"] == 80
    assert response.data["source_device"] == str(device.uuid)
    listening.refresh_from_db()
    assert listening.duration_seconds == 80
    assert listening.source_device_id == device.pk


def test_by_session_unknown_404(factories, logged_in_api_client):
    response = logged_in_api_client.patch(
        _by_session_url(uuid.uuid4()),
        {"duration_seconds": 10},
        format="json",
    )
    assert response.status_code == 404


def test_by_session_other_user_404(factories, logged_in_api_client):
    other = factories["users.User"]()
    session_id = uuid.uuid4()
    factories["history.Listening"](
        user=other,
        duration_seconds=10,
        client_session_id=session_id,
    )

    response = logged_in_api_client.patch(
        _by_session_url(session_id),
        {"duration_seconds": 99},
        format="json",
    )
    assert response.status_code == 404


def test_put_not_allowed(factories, logged_in_api_client):
    listening = factories["history.Listening"](user=logged_in_api_client.user)

    response = logged_in_api_client.put(
        _detail_url(listening.pk),
        {"duration_seconds": 10},
        format="json",
    )
    assert response.status_code == 405


def test_throttling_scopes_configured():
    from funkwhale_api.history.views import ListeningViewSet

    assert ListeningViewSet.throttling_scopes["partial_update"]["authenticated"] == (
        "authenticated-listening-update"
    )
    assert ListeningViewSet.throttling_scopes["by_session"]["authenticated"] == (
        "authenticated-listening-update"
    )
