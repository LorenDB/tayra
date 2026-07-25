import uuid

import pytest
from django.db import IntegrityError
from django.urls import reverse
from django.utils import timezone

from funkwhale_api.client_data import models
from funkwhale_api.client_data.sensitive import is_sensitive_key
from funkwhale_api.client_data.serializers import (
    MAX_KEYS_PER_SCOPE,
    MAX_PAYLOAD_BYTES,
    MAX_VALUE_BYTES,
)


def _list_url():
    return reverse("api:v1:client_data:client-preferences-list")


def _put(client, payload, **kwargs):
    return client.put(_list_url(), payload, format="json", **kwargs)


def _get(client, **params):
    return client.get(_list_url(), params)


# ---------------------------------------------------------------------------
# Sensitive key denylist unit tests
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "key",
    [
        "access_token",
        "refresh_token",
        "oauth_token",
        "my_password",
        "client_secret",
        "api_key",
        "api-key",
        "api.key",
        "openai_api_key",
        "groq_api_key",
        "open_router_api_key",
        "openrouter_api_key",
        "custom_endpoint_api_key",
        "someApikeyThing",
        "private_key",
        "ssh_private_key",
        "nc_app_password",
        "nc_login_flow",
        "TOKEN",
        "Password",
    ],
)
def test_is_sensitive_key_rejects(key):
    assert is_sensitive_key(key) is True


@pytest.mark.parametrize(
    "key",
    [
        "gapless_playback",
        "browse_mode",
        "server_url",
        "custom_endpoint_url",
        "ai_enabled",
        "ai_provider_type",
        "nc_server",
        "analytics_enabled",
        "cache_size_limit_mb",
    ],
)
def test_is_sensitive_key_allows(key):
    assert is_sensitive_key(key) is False


# ---------------------------------------------------------------------------
# Model uniqueness
# ---------------------------------------------------------------------------


def test_account_level_unique_constraint(factories):
    """Two account-level rows with same (user, client_id, key) must fail."""
    user = factories["users.User"]()
    models.ClientPreference.objects.create(
        user=user, client_id="tayra", device=None, key="theme", value="dark"
    )
    with pytest.raises(IntegrityError):
        models.ClientPreference.objects.create(
            user=user, client_id="tayra", device=None, key="theme", value="light"
        )


def test_device_scoped_unique_constraint(factories):
    """Same device + same key must raise IntegrityError (device partial unique)."""
    user = factories["users.User"]()
    device = factories["client_data.ClientDevice"](user=user)
    models.ClientPreference.objects.create(
        user=user, client_id="tayra", device=device, key="cache", value=100
    )
    with pytest.raises(IntegrityError):
        models.ClientPreference.objects.create(
            user=user, client_id="tayra", device=device, key="cache", value=200
        )


def test_device_scoped_same_key_allowed_on_different_devices(factories, db):
    user = factories["users.User"]()
    d1 = factories["client_data.ClientDevice"](user=user)
    d2 = factories["client_data.ClientDevice"](user=user)
    models.ClientPreference.objects.create(
        user=user, client_id="tayra", device=d1, key="cache", value=100
    )
    models.ClientPreference.objects.create(
        user=user, client_id="tayra", device=d2, key="cache", value=200
    )
    assert models.ClientPreference.objects.filter(user=user, key="cache").count() == 2


def test_account_and_device_may_share_key(factories, db):
    user = factories["users.User"]()
    device = factories["client_data.ClientDevice"](user=user)
    models.ClientPreference.objects.create(
        user=user, client_id="tayra", device=None, key="theme", value="dark"
    )
    models.ClientPreference.objects.create(
        user=user, client_id="tayra", device=device, key="theme", value="light"
    )
    assert models.ClientPreference.objects.filter(user=user, key="theme").count() == 2


# ---------------------------------------------------------------------------
# PUT merge / replace
# ---------------------------------------------------------------------------


def test_put_merge_creates_account_prefs(factories, logged_in_api_client):
    payload = {
        "client_id": "tayra",
        "device_uuid": None,
        "preferences": {
            "gapless_playback": True,
            "browse_mode": "albums",
        },
        "mode": "merge",
    }
    response = _put(logged_in_api_client, payload)

    assert response.status_code == 200
    assert response.data["client_id"] == "tayra"
    assert response.data["device_uuid"] is None
    assert response.data["mode"] == "merge"
    assert response.data["resolved"] is False
    assert response.data["count"] == 2
    keys = {r["key"]: r["value"] for r in response.data["results"]}
    assert keys["gapless_playback"] is True
    assert keys["browse_mode"] == "albums"

    assert (
        models.ClientPreference.objects.filter(
            user=logged_in_api_client.user, client_id="tayra", device__isnull=True
        ).count()
        == 2
    )


def test_put_merge_upserts_existing(factories, logged_in_api_client):
    factories["client_data.ClientPreference"](
        user=logged_in_api_client.user,
        client_id="tayra",
        key="browse_mode",
        value="tracks",
    )
    payload = {
        "client_id": "tayra",
        "preferences": {"browse_mode": "albums", "gapless_playback": True},
        "mode": "merge",
    }
    response = _put(logged_in_api_client, payload)

    assert response.status_code == 200
    assert response.data["count"] == 2
    row = models.ClientPreference.objects.get(
        user=logged_in_api_client.user, key="browse_mode", device__isnull=True
    )
    assert row.value == "albums"


def test_put_replace_deletes_missing_keys(factories, logged_in_api_client):
    factories["client_data.ClientPreference"](
        user=logged_in_api_client.user,
        client_id="tayra",
        key="old_key",
        value=1,
    )
    factories["client_data.ClientPreference"](
        user=logged_in_api_client.user,
        client_id="tayra",
        key="keep_me",
        value=2,
    )
    payload = {
        "client_id": "tayra",
        "preferences": {"keep_me": 3, "new_key": 4},
        "mode": "replace",
    }
    response = _put(logged_in_api_client, payload)

    assert response.status_code == 200
    assert response.data["count"] == 2
    keys = set(
        models.ClientPreference.objects.filter(
            user=logged_in_api_client.user, client_id="tayra"
        ).values_list("key", flat=True)
    )
    assert keys == {"keep_me", "new_key"}
    assert (
        models.ClientPreference.objects.get(
            user=logged_in_api_client.user, key="keep_me"
        ).value
        == 3
    )


def test_put_replace_device_does_not_wipe_account(factories, logged_in_api_client):
    """Replace on a device scope must leave account-level and other devices intact."""
    user = logged_in_api_client.user
    d1 = factories["client_data.ClientDevice"](user=user)
    d2 = factories["client_data.ClientDevice"](user=user)
    factories["client_data.ClientPreference"](
        user=user, client_id="tayra", key="theme", value="dark"
    )
    factories["client_data.ClientPreference"](
        user=user, client_id="tayra", device=d1, key="cache", value=64
    )
    factories["client_data.ClientPreference"](
        user=user, client_id="tayra", device=d1, key="old_device", value=1
    )
    factories["client_data.ClientPreference"](
        user=user, client_id="tayra", device=d2, key="other_cache", value=128
    )

    response = _put(
        logged_in_api_client,
        {
            "client_id": "tayra",
            "device_uuid": str(d1.uuid),
            "preferences": {"cache": 256},
            "mode": "replace",
        },
    )

    assert response.status_code == 200
    assert response.data["count"] == 1
    assert response.data["results"][0]["key"] == "cache"
    assert response.data["results"][0]["value"] == 256
    # Account-level preserved
    assert models.ClientPreference.objects.filter(
        user=user, device__isnull=True, key="theme", value="dark"
    ).exists()
    # Other device preserved
    assert models.ClientPreference.objects.filter(
        user=user, device=d2, key="other_cache", value=128
    ).exists()
    # Old key on d1 removed by replace
    assert not models.ClientPreference.objects.filter(
        user=user, device=d1, key="old_device"
    ).exists()


def test_put_default_mode_is_merge(factories, logged_in_api_client):
    factories["client_data.ClientPreference"](
        user=logged_in_api_client.user,
        client_id="tayra",
        key="existing",
        value=True,
    )
    payload = {
        "client_id": "tayra",
        "preferences": {"new_key": False},
        # mode omitted
    }
    response = _put(logged_in_api_client, payload)

    assert response.status_code == 200
    assert response.data["mode"] == "merge"
    assert (
        models.ClientPreference.objects.filter(
            user=logged_in_api_client.user, client_id="tayra"
        ).count()
        == 2
    )


def test_put_device_scoped(factories, logged_in_api_client):
    device = factories["client_data.ClientDevice"](user=logged_in_api_client.user)
    payload = {
        "client_id": "tayra",
        "device_uuid": str(device.uuid),
        "preferences": {"cache_size_limit_mb": 512},
        "mode": "merge",
    }
    response = _put(logged_in_api_client, payload)

    assert response.status_code == 200
    assert response.data["device_uuid"] == str(device.uuid)
    assert response.data["resolved"] is False
    pref = models.ClientPreference.objects.get()
    assert pref.device_id == device.id
    assert pref.value == 512
    assert response.data["results"][0]["device_uuid"] == str(device.uuid)


def test_put_unknown_device_rejected(factories, logged_in_api_client):
    payload = {
        "client_id": "tayra",
        "device_uuid": str(uuid.uuid4()),
        "preferences": {"x": 1},
    }
    response = _put(logged_in_api_client, payload)

    assert response.status_code == 400
    assert response.data["device_uuid"][0]["code"] == "device_not_registered"


def test_put_inactive_device_rejected(factories, logged_in_api_client):
    device = factories["client_data.ClientDevice"](
        user=logged_in_api_client.user, is_active=False
    )
    payload = {
        "client_id": "tayra",
        "device_uuid": str(device.uuid),
        "preferences": {"x": 1},
    }
    response = _put(logged_in_api_client, payload)

    assert response.status_code == 400
    assert response.data["device_uuid"][0]["code"] == "device_inactive"


def test_put_invalid_device_uuid_coded_error(factories, logged_in_api_client):
    """PUT invalid UUID must use structured {code, detail}, same as GET."""
    response = _put(
        logged_in_api_client,
        {
            "client_id": "tayra",
            "device_uuid": "not-a-uuid",
            "preferences": {"x": 1},
        },
    )
    assert response.status_code == 400
    assert response.data["device_uuid"][0]["code"] == "invalid"


# ---------------------------------------------------------------------------
# Sensitive keys / size limits via API
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "key",
    ["oauth_token", "groq_api_key", "nc_app_password", "my_api_key", "api-key"],
)
def test_put_rejects_sensitive_keys(factories, logged_in_api_client, key):
    payload = {
        "client_id": "tayra",
        "preferences": {key: "s3cret"},
    }
    response = _put(logged_in_api_client, payload)

    assert response.status_code == 400
    assert response.data["preferences"][0]["code"] == "sensitive_key_rejected"
    assert models.ClientPreference.objects.count() == 0


def test_put_rejects_oversized_value(factories, logged_in_api_client):
    big = "x" * (MAX_VALUE_BYTES + 1)
    payload = {
        "client_id": "tayra",
        "preferences": {"big_blob": big},
    }
    response = _put(logged_in_api_client, payload)

    assert response.status_code == 400
    assert response.data["preferences"][0]["code"] == "value_too_large"


def test_put_rejects_too_many_keys_in_payload(factories, logged_in_api_client):
    prefs = {f"k{i}": i for i in range(MAX_KEYS_PER_SCOPE + 1)}
    payload = {"client_id": "tayra", "preferences": prefs, "mode": "replace"}
    response = _put(logged_in_api_client, payload)

    assert response.status_code == 400
    assert response.data["preferences"][0]["code"] == "too_many_keys"


def test_put_merge_rejects_exceeding_scope_cap(factories, logged_in_api_client):
    # Pre-fill to cap - 1, then add 2 new keys.
    # bulk_create skips auto_now — set updated_at explicitly (PostgreSQL NOT NULL).
    user = logged_in_api_client.user
    now = timezone.now()
    models.ClientPreference.objects.bulk_create(
        [
            models.ClientPreference(
                user=user,
                client_id="tayra",
                device=None,
                key=f"e{i}",
                value=i,
                updated_at=now,
            )
            for i in range(MAX_KEYS_PER_SCOPE - 1)
        ]
    )
    payload = {
        "client_id": "tayra",
        "preferences": {"new_a": 1, "new_b": 2},
        "mode": "merge",
    }
    response = _put(logged_in_api_client, payload)

    assert response.status_code == 400
    assert response.data["preferences"][0]["code"] == "too_many_keys"


def test_put_rejects_payload_too_large(factories, logged_in_api_client):
    """Preferences object just over 256 KiB → payload_too_large (not whole body)."""
    # ~2 KiB per value, under per-value 8 KiB; enough keys to exceed 256 KiB total.
    chunk = "x" * 2000
    n_keys = (MAX_PAYLOAD_BYTES // 2000) + 10  # comfortably over 256 KiB of content
    assert n_keys < MAX_KEYS_PER_SCOPE  # stay under key-count limit
    prefs = {f"k{i:03d}": chunk for i in range(n_keys)}
    payload = {"client_id": "tayra", "preferences": prefs, "mode": "replace"}
    response = _put(logged_in_api_client, payload)

    assert response.status_code == 400
    assert response.data["preferences"][0]["code"] == "payload_too_large"


# ---------------------------------------------------------------------------
# GET + resolution
# ---------------------------------------------------------------------------


def test_get_requires_client_id(factories, logged_in_api_client):
    response = _get(logged_in_api_client)
    assert response.status_code == 400
    assert response.data["client_id"][0]["code"] == "required"


def test_get_account_level_only(factories, logged_in_api_client):
    user = logged_in_api_client.user
    device = factories["client_data.ClientDevice"](user=user)
    factories["client_data.ClientPreference"](
        user=user, client_id="tayra", key="theme", value="dark"
    )
    factories["client_data.ClientPreference"](
        user=user, client_id="tayra", device=device, key="cache", value=64
    )
    # other client
    factories["client_data.ClientPreference"](
        user=user, client_id="other", key="theme", value="x"
    )

    response = _get(logged_in_api_client, client_id="tayra")

    assert response.status_code == 200
    assert response.data["count"] == 1
    assert response.data["results"][0]["key"] == "theme"
    assert response.data["results"][0]["device_uuid"] is None


def test_get_device_overrides_account(factories, logged_in_api_client):
    user = logged_in_api_client.user
    device = factories["client_data.ClientDevice"](user=user)
    factories["client_data.ClientPreference"](
        user=user, client_id="tayra", key="theme", value="dark"
    )
    factories["client_data.ClientPreference"](
        user=user, client_id="tayra", key="shared", value="account"
    )
    factories["client_data.ClientPreference"](
        user=user,
        client_id="tayra",
        device=device,
        key="shared",
        value="device",
    )
    factories["client_data.ClientPreference"](
        user=user,
        client_id="tayra",
        device=device,
        key="local_only",
        value=True,
    )

    response = _get(
        logged_in_api_client, client_id="tayra", device_uuid=str(device.uuid)
    )

    assert response.status_code == 200
    by_key = {r["key"]: r for r in response.data["results"]}
    assert set(by_key) == {"theme", "shared", "local_only"}
    assert by_key["theme"]["value"] == "dark"
    assert by_key["theme"]["device_uuid"] is None
    assert by_key["shared"]["value"] == "device"
    assert by_key["shared"]["device_uuid"] == str(device.uuid)
    assert by_key["local_only"]["value"] is True


def test_get_unknown_device(factories, logged_in_api_client):
    response = _get(
        logged_in_api_client, client_id="tayra", device_uuid=str(uuid.uuid4())
    )
    assert response.status_code == 400
    assert response.data["device_uuid"][0]["code"] == "device_not_registered"


def test_get_own_prefs_only(factories, logged_in_api_client):
    other = factories["users.User"]()
    factories["client_data.ClientPreference"](
        user=other, client_id="tayra", key="secret", value=1
    )
    factories["client_data.ClientPreference"](
        user=logged_in_api_client.user, client_id="tayra", key="mine", value=2
    )

    response = _get(logged_in_api_client, client_id="tayra")

    assert response.status_code == 200
    assert response.data["count"] == 1
    assert response.data["results"][0]["key"] == "mine"


def test_anonymous_denied(db, api_client, preferences):
    preferences["common__api_authentication_required"] = False
    response = _get(api_client, client_id="tayra")
    assert response.status_code in (401, 403)

    response = _put(
        api_client,
        {"client_id": "tayra", "preferences": {"x": 1}},
    )
    assert response.status_code in (401, 403)


def test_oauth_token_without_client_data_scope_denied(factories, api_client):
    user = factories["users.User"]()
    scope = "read:listenings write:listenings"
    token = factories["users.AccessToken"](
        user=user,
        scope=scope,
        application__scope=scope,
    )
    auth = f"Bearer {token.token}"

    response = api_client.get(
        _list_url(), {"client_id": "tayra"}, HTTP_AUTHORIZATION=auth
    )
    assert response.status_code == 403

    response = api_client.put(
        _list_url(),
        {"client_id": "tayra", "preferences": {"x": 1}},
        format="json",
        HTTP_AUTHORIZATION=auth,
    )
    assert response.status_code == 403


def test_oauth_token_with_client_data_scope_allowed(factories, api_client):
    user = factories["users.User"]()
    scope = "read:client_data write:client_data"
    token = factories["users.AccessToken"](
        user=user,
        scope=scope,
        application__scope=scope,
    )
    auth = f"Bearer {token.token}"

    response = api_client.put(
        _list_url(),
        {
            "client_id": "tayra",
            "preferences": {"gapless_playback": True},
            "mode": "merge",
        },
        format="json",
        HTTP_AUTHORIZATION=auth,
    )
    assert response.status_code == 200

    response = api_client.get(
        _list_url(), {"client_id": "tayra"}, HTTP_AUTHORIZATION=auth
    )
    assert response.status_code == 200
    assert response.data["count"] == 1


def test_oauth_read_only_allows_get_denies_put(factories, api_client):
    user = factories["users.User"]()
    factories["client_data.ClientPreference"](
        user=user, client_id="tayra", key="mine", value=1
    )
    scope = "read:client_data"
    token = factories["users.AccessToken"](
        user=user,
        scope=scope,
        application__scope=scope,
    )
    auth = f"Bearer {token.token}"

    response = api_client.get(
        _list_url(), {"client_id": "tayra"}, HTTP_AUTHORIZATION=auth
    )
    assert response.status_code == 200

    response = api_client.put(
        _list_url(),
        {"client_id": "tayra", "preferences": {"x": 1}},
        format="json",
        HTTP_AUTHORIZATION=auth,
    )
    assert response.status_code == 403


def test_oauth_write_only_allows_put_denies_get(factories, api_client):
    user = factories["users.User"]()
    scope = "write:client_data"
    token = factories["users.AccessToken"](
        user=user,
        scope=scope,
        application__scope=scope,
    )
    auth = f"Bearer {token.token}"

    response = api_client.put(
        _list_url(),
        {"client_id": "tayra", "preferences": {"gapless_playback": True}},
        format="json",
        HTTP_AUTHORIZATION=auth,
    )
    assert response.status_code == 200

    response = api_client.get(
        _list_url(), {"client_id": "tayra"}, HTTP_AUTHORIZATION=auth
    )
    assert response.status_code == 403
