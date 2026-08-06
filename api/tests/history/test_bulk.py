import datetime
import uuid

import pytest
from django.urls import reverse
from django.utils import timezone

from funkwhale_api.history import bulk as bulk_module
from funkwhale_api.history import models


def _bulk_url():
    return reverse("api:v1:history:listenings-bulk")


def _iso(dt):
    return dt.isoformat().replace("+00:00", "Z")


def test_bulk_create_only_new_rows(
    factories, logged_in_api_client, activity_muted, mocker
):
    track = factories["music.Track"]()
    device = factories["client_data.ClientDevice"](user=logged_in_api_client.user)
    plugin_hook = mocker.patch("config.plugins.trigger_hook")
    past = timezone.now() - datetime.timedelta(days=30)

    payload = {
        "mode": "enrich_or_create",
        "items": [
            {
                "track": track.pk,
                "creation_date": _iso(past),
                "duration_seconds": 120,
                "source_device": str(device.uuid),
                "client_session_id": str(uuid.uuid4()),
            },
            {
                "track": track.pk,
                "creation_date": _iso(past + datetime.timedelta(hours=1)),
                "duration_seconds": 90,
            },
        ],
    }
    response = logged_in_api_client.post(_bulk_url(), payload, format="json")

    assert response.status_code == 200
    assert response.data["created"] == 2
    assert response.data["enriched"] == 0
    assert response.data["skipped_duplicate"] == 0
    assert response.data["errors"] == []
    created = models.Listening.objects.filter(user=logged_in_api_client.user)
    assert created.count() == 2
    # bulk_create does not apply auto_now — updated_at must be set explicitly
    for listening in created:
        assert listening.updated_at is not None
    # Bulk must never fire plugins or activity
    plugin_hook.assert_not_called()
    activity_muted.assert_not_called()


def test_bulk_does_not_window_match_stock_thin_row(
    factories, logged_in_api_client, activity_muted, mocker
):
    """Stock thin scrobbles are ignored for window match — import creates a new rich row."""
    track = factories["music.Track"]()
    device = factories["client_data.ClientDevice"](user=logged_in_api_client.user)
    listened_at = timezone.now() - datetime.timedelta(days=7)
    stock = factories["history.Listening"](
        user=logged_in_api_client.user,
        track=track,
        creation_date=listened_at,
        duration_seconds=None,
        source_device=None,
        client_session_id=None,
    )
    plugin_hook = mocker.patch("config.plugins.trigger_hook")

    rich_at = listened_at + datetime.timedelta(seconds=1)
    response = logged_in_api_client.post(
        _bulk_url(),
        {
            "mode": "enrich_or_create",
            "dedup_window_seconds": 2,
            "items": [
                {
                    "track": track.pk,
                    "creation_date": _iso(rich_at),
                    "duration_seconds": 200,
                    "source_device": str(device.uuid),
                }
            ],
        },
        format="json",
    )

    assert response.status_code == 200
    assert response.data["created"] == 1
    assert response.data["enriched"] == 0
    assert response.data["skipped_duplicate"] == 0
    assert response.data["errors"] == []
    assert models.Listening.objects.count() == 2

    stock.refresh_from_db()
    assert stock.duration_seconds is None
    assert stock.source_device_id is None
    rich = models.Listening.objects.exclude(pk=stock.pk).get()
    assert rich.duration_seconds == 200
    assert rich.source_device_id == device.pk
    plugin_hook.assert_not_called()
    activity_muted.assert_not_called()


def test_bulk_enrich_is_noop_when_already_equal(
    factories, logged_in_api_client, mocker
):
    track = factories["music.Track"]()
    device = factories["client_data.ClientDevice"](user=logged_in_api_client.user)
    when = timezone.now() - datetime.timedelta(days=3)
    factories["history.Listening"](
        user=logged_in_api_client.user,
        track=track,
        creation_date=when,
        duration_seconds=50,
        source_device=device,
    )
    mocker.patch("config.plugins.trigger_hook")

    response = logged_in_api_client.post(
        _bulk_url(),
        {
            "items": [
                {
                    "track": track.pk,
                    "creation_date": _iso(when),
                    "duration_seconds": 50,
                    "source_device": str(device.uuid),
                }
            ]
        },
        format="json",
    )

    assert response.status_code == 200
    assert response.data["created"] == 0
    assert response.data["enriched"] == 0
    assert response.data["skipped_duplicate"] == 1
    assert models.Listening.objects.count() == 1


def test_bulk_enrich_never_decreases_duration(factories, logged_in_api_client, mocker):
    track = factories["music.Track"]()
    when = timezone.now() - datetime.timedelta(days=2)
    factories["history.Listening"](
        user=logged_in_api_client.user,
        track=track,
        creation_date=when,
        duration_seconds=100,
    )
    mocker.patch("config.plugins.trigger_hook")

    response = logged_in_api_client.post(
        _bulk_url(),
        {
            "items": [
                {
                    "track": track.pk,
                    "creation_date": _iso(when),
                    "duration_seconds": 40,
                }
            ]
        },
        format="json",
    )

    assert response.status_code == 200
    assert response.data["skipped_duplicate"] == 1
    assert response.data["enriched"] == 0
    assert models.Listening.objects.get().duration_seconds == 100


def test_bulk_create_only_skips_match(factories, logged_in_api_client, mocker):
    track = factories["music.Track"]()
    when = timezone.now() - datetime.timedelta(days=1)
    factories["history.Listening"](
        user=logged_in_api_client.user,
        track=track,
        creation_date=when,
        duration_seconds=100,
    )
    mocker.patch("config.plugins.trigger_hook")

    response = logged_in_api_client.post(
        _bulk_url(),
        {
            "mode": "create_only",
            "items": [
                {
                    "track": track.pk,
                    "creation_date": _iso(when),
                    "duration_seconds": 200,
                }
            ],
        },
        format="json",
    )

    assert response.status_code == 200
    assert response.data["created"] == 0
    assert response.data["enriched"] == 0
    assert response.data["skipped_duplicate"] == 1
    assert models.Listening.objects.get().duration_seconds == 100


def test_bulk_session_match_wins_over_window(factories, logged_in_api_client, mocker):
    track = factories["music.Track"]()
    session_id = uuid.uuid4()
    # Existing session row far from import timestamp
    existing_when = timezone.now() - datetime.timedelta(days=10)
    factories["history.Listening"](
        user=logged_in_api_client.user,
        track=track,
        creation_date=existing_when,
        duration_seconds=10,
        client_session_id=session_id,
    )
    # Thin stock row near import time (would otherwise window-match)
    import_when = timezone.now() - datetime.timedelta(days=1)
    factories["history.Listening"](
        user=logged_in_api_client.user,
        track=track,
        creation_date=import_when,
        duration_seconds=None,
        client_session_id=None,
    )
    mocker.patch("config.plugins.trigger_hook")

    response = logged_in_api_client.post(
        _bulk_url(),
        {
            "items": [
                {
                    "track": track.pk,
                    "creation_date": _iso(import_when),
                    "duration_seconds": 80,
                    "client_session_id": str(session_id),
                }
            ]
        },
        format="json",
    )

    assert response.status_code == 200
    assert response.data["enriched"] == 1
    assert response.data["created"] == 0
    session_row = models.Listening.objects.get(client_session_id=session_id)
    assert session_row.duration_seconds == 80
    # Window candidate must stay thin
    thin = models.Listening.objects.get(client_session_id__isnull=True)
    assert thin.duration_seconds is None


def test_bulk_window_match_only_considers_rich_rows(
    factories, logged_in_api_client, mocker
):
    """Thin stock candidates are not window-matched; only rich rows enrich."""
    track = factories["music.Track"]()
    when = timezone.now() - datetime.timedelta(days=5)
    rich = factories["history.Listening"](
        user=logged_in_api_client.user,
        track=track,
        creation_date=when,
        duration_seconds=30,
    )
    thin = factories["history.Listening"](
        user=logged_in_api_client.user,
        track=track,
        creation_date=when,
        duration_seconds=None,
    )
    mocker.patch("config.plugins.trigger_hook")

    response = logged_in_api_client.post(
        _bulk_url(),
        {
            "items": [
                {
                    "track": track.pk,
                    "creation_date": _iso(when),
                    "duration_seconds": 99,
                }
            ]
        },
        format="json",
    )

    assert response.status_code == 200
    assert response.data["enriched"] == 1
    thin.refresh_from_db()
    rich.refresh_from_db()
    assert thin.duration_seconds is None
    assert rich.duration_seconds == 99


def test_bulk_window_tie_break_closest_time(factories, logged_in_api_client, mocker):
    track = factories["music.Track"]()
    base = timezone.now() - datetime.timedelta(days=4)
    farther = factories["history.Listening"](
        user=logged_in_api_client.user,
        track=track,
        creation_date=base,
        duration_seconds=1,  # rich so it is a window candidate
    )
    closer = factories["history.Listening"](
        user=logged_in_api_client.user,
        track=track,
        creation_date=base + datetime.timedelta(seconds=1),
        duration_seconds=2,  # rich window candidate
    )
    mocker.patch("config.plugins.trigger_hook")

    target = base + datetime.timedelta(seconds=1)
    response = logged_in_api_client.post(
        _bulk_url(),
        {
            "dedup_window_seconds": 2,
            "items": [
                {
                    "track": track.pk,
                    "creation_date": _iso(target),
                    "duration_seconds": 55,
                }
            ],
        },
        format="json",
    )

    assert response.status_code == 200
    assert response.data["enriched"] == 1
    closer.refresh_from_db()
    farther.refresh_from_db()
    assert closer.duration_seconds == 55
    assert farther.duration_seconds == 1  # unchanged


def test_bulk_window_tie_break_lowest_id(factories, logged_in_api_client, mocker):
    """Equal Δ among rich rows → enrich the lowest id."""
    track = factories["music.Track"]()
    when = timezone.now() - datetime.timedelta(days=5)
    first = factories["history.Listening"](
        user=logged_in_api_client.user,
        track=track,
        creation_date=when,
        duration_seconds=1,
    )
    second = factories["history.Listening"](
        user=logged_in_api_client.user,
        track=track,
        creation_date=when,
        duration_seconds=1,
    )
    assert first.pk < second.pk
    mocker.patch("config.plugins.trigger_hook")

    response = logged_in_api_client.post(
        _bulk_url(),
        {
            "items": [
                {
                    "track": track.pk,
                    "creation_date": _iso(when),
                    "duration_seconds": 42,
                }
            ]
        },
        format="json",
    )

    assert response.status_code == 200
    assert response.data["enriched"] == 1
    first.refresh_from_db()
    second.refresh_from_db()
    assert first.duration_seconds == 42
    assert second.duration_seconds == 1


def test_bulk_outside_window_creates(factories, logged_in_api_client, mocker):
    track = factories["music.Track"]()
    when = timezone.now() - datetime.timedelta(days=6)
    factories["history.Listening"](
        user=logged_in_api_client.user,
        track=track,
        creation_date=when,
        duration_seconds=5,  # existing rich row outside window
    )
    mocker.patch("config.plugins.trigger_hook")

    far = when + datetime.timedelta(seconds=10)
    response = logged_in_api_client.post(
        _bulk_url(),
        {
            "dedup_window_seconds": 2,
            "items": [
                {
                    "track": track.pk,
                    "creation_date": _iso(far),
                    "duration_seconds": 10,
                }
            ],
        },
        format="json",
    )

    assert response.status_code == 200
    assert response.data["created"] == 1
    assert models.Listening.objects.count() == 2


def test_bulk_track_not_found_per_row(factories, logged_in_api_client, mocker):
    track = factories["music.Track"]()
    mocker.patch("config.plugins.trigger_hook")
    when = timezone.now() - datetime.timedelta(days=1)

    response = logged_in_api_client.post(
        _bulk_url(),
        {
            "items": [
                {"track": 99999999, "creation_date": _iso(when), "duration_seconds": 1},
                {
                    "track": track.pk,
                    "creation_date": _iso(when),
                    "duration_seconds": 2,
                },
            ]
        },
        format="json",
    )

    assert response.status_code == 200
    assert response.data["created"] == 1
    assert len(response.data["errors"]) == 1
    assert response.data["errors"][0]["index"] == 0
    assert response.data["errors"][0]["code"] == "track_not_found"
    assert models.Listening.objects.count() == 1


def test_bulk_device_not_registered(factories, logged_in_api_client, mocker):
    track = factories["music.Track"]()
    mocker.patch("config.plugins.trigger_hook")
    when = timezone.now() - datetime.timedelta(days=1)

    response = logged_in_api_client.post(
        _bulk_url(),
        {
            "items": [
                {
                    "track": track.pk,
                    "creation_date": _iso(when),
                    "source_device": str(uuid.uuid4()),
                }
            ]
        },
        format="json",
    )

    assert response.status_code == 200
    assert response.data["created"] == 0
    assert response.data["errors"][0]["code"] == "device_not_registered"
    assert models.Listening.objects.count() == 0


def test_bulk_device_inactive(factories, logged_in_api_client, mocker):
    track = factories["music.Track"]()
    device = factories["client_data.ClientDevice"](
        user=logged_in_api_client.user, is_active=False
    )
    mocker.patch("config.plugins.trigger_hook")
    when = timezone.now() - datetime.timedelta(days=1)

    response = logged_in_api_client.post(
        _bulk_url(),
        {
            "items": [
                {
                    "track": track.pk,
                    "creation_date": _iso(when),
                    "source_device": str(device.uuid),
                }
            ]
        },
        format="json",
    )

    assert response.status_code == 200
    assert response.data["errors"][0]["code"] == "device_inactive"


def test_bulk_batch_too_large(factories, logged_in_api_client):
    track = factories["music.Track"]()
    when = timezone.now() - datetime.timedelta(days=1)
    items = [
        {"track": track.pk, "creation_date": _iso(when)}
        for _ in range(bulk_module.BULK_MAX_ITEMS + 1)
    ]
    response = logged_in_api_client.post(_bulk_url(), {"items": items}, format="json")

    assert response.status_code == 400
    assert response.data["items"][0]["code"] == "batch_too_large"


def test_bulk_empty_items(logged_in_api_client):
    response = logged_in_api_client.post(_bulk_url(), {"items": []}, format="json")
    assert response.status_code == 400
    assert response.data["items"][0]["code"] == "empty_items"


def test_bulk_empty_body(logged_in_api_client):
    response = logged_in_api_client.post(_bulk_url(), {}, format="json")
    assert response.status_code == 400
    assert response.data["items"][0]["code"] == "empty_items"


def test_bulk_creation_date_required(factories, logged_in_api_client):
    track = factories["music.Track"]()
    response = logged_in_api_client.post(
        _bulk_url(),
        {"items": [{"track": track.pk, "duration_seconds": 10}]},
        format="json",
    )
    assert response.status_code == 400
    assert "creation_date" in response.data["items"][0]


def test_bulk_trigger_side_effects_rejected(factories, logged_in_api_client):
    track = factories["music.Track"]()
    when = timezone.now() - datetime.timedelta(days=1)
    response = logged_in_api_client.post(
        _bulk_url(),
        {
            "trigger_side_effects": True,
            "items": [{"track": track.pk, "creation_date": _iso(when)}],
        },
        format="json",
    )
    assert response.status_code == 400
    assert (
        response.data["trigger_side_effects"][0]["code"] == "side_effects_not_allowed"
    )


def test_bulk_requires_auth(api_client, factories, preferences):
    preferences["common__api_authentication_required"] = False
    track = factories["music.Track"]()
    when = timezone.now() - datetime.timedelta(days=1)
    response = api_client.post(
        _bulk_url(),
        {"items": [{"track": track.pk, "creation_date": _iso(when)}]},
        format="json",
    )
    # write:listenings not in ANONYMOUS_SCOPES
    assert response.status_code in (401, 403)


def test_bulk_default_mode_is_enrich_or_create(factories, logged_in_api_client, mocker):
    track = factories["music.Track"]()
    when = timezone.now() - datetime.timedelta(days=2)
    factories["history.Listening"](
        user=logged_in_api_client.user,
        track=track,
        creation_date=when,
        duration_seconds=5,  # existing rich row
    )
    mocker.patch("config.plugins.trigger_hook")

    # Omit mode — should enrich the rich row
    response = logged_in_api_client.post(
        _bulk_url(),
        {
            "items": [
                {
                    "track": track.pk,
                    "creation_date": _iso(when),
                    "duration_seconds": 15,
                }
            ]
        },
        format="json",
    )
    assert response.status_code == 200
    assert response.data["enriched"] == 1


def test_bulk_within_batch_session_dedup(factories, logged_in_api_client, mocker):
    """Two items same client_session_id in one batch → one create, one enrich."""
    track = factories["music.Track"]()
    session_id = uuid.uuid4()
    when = timezone.now() - datetime.timedelta(days=1)
    mocker.patch("config.plugins.trigger_hook")

    response = logged_in_api_client.post(
        _bulk_url(),
        {
            "items": [
                {
                    "track": track.pk,
                    "creation_date": _iso(when),
                    "duration_seconds": 10,
                    "client_session_id": str(session_id),
                },
                {
                    "track": track.pk,
                    "creation_date": _iso(when + datetime.timedelta(seconds=1)),
                    "duration_seconds": 40,
                    "client_session_id": str(session_id),
                },
            ]
        },
        format="json",
    )

    assert response.status_code == 200
    assert response.data["created"] == 1
    assert response.data["enriched"] == 1
    assert models.Listening.objects.count() == 1
    assert models.Listening.objects.get().duration_seconds == 40


def test_bulk_idempotent_rerun(factories, logged_in_api_client, mocker):
    track = factories["music.Track"]()
    device = factories["client_data.ClientDevice"](user=logged_in_api_client.user)
    when = timezone.now() - datetime.timedelta(days=8)
    mocker.patch("config.plugins.trigger_hook")
    items = [
        {
            "track": track.pk,
            "creation_date": _iso(when),
            "duration_seconds": 77,
            "source_device": str(device.uuid),
        }
    ]

    first = logged_in_api_client.post(_bulk_url(), {"items": items}, format="json")
    second = logged_in_api_client.post(_bulk_url(), {"items": items}, format="json")

    assert first.status_code == 200
    assert first.data["created"] == 1
    assert second.status_code == 200
    assert second.data["skipped_duplicate"] == 1
    assert models.Listening.objects.count() == 1


def test_process_bulk_listenings_unit_empty(factories):
    user = factories["users.User"]()
    result = bulk_module.process_bulk_listenings(
        user, mode="enrich_or_create", items=[], dedup_window_seconds=2
    )
    assert result == {
        "created": 0,
        "enriched": 0,
        "skipped_duplicate": 0,
        "errors": [],
    }


@pytest.mark.parametrize(
    "seconds",
    [86401, -1],
)
def test_bulk_duration_bounds(factories, logged_in_api_client, seconds):
    track = factories["music.Track"]()
    when = timezone.now() - datetime.timedelta(days=1)
    response = logged_in_api_client.post(
        _bulk_url(),
        {
            "items": [
                {
                    "track": track.pk,
                    "creation_date": _iso(when),
                    "duration_seconds": seconds,
                }
            ]
        },
        format="json",
    )
    assert response.status_code == 400
