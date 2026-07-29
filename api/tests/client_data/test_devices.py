import uuid

from django.urls import reverse

from funkwhale_api.client_data import models


def _list_url():
    return reverse("api:v1:client_data:client-devices-list")


def _detail_url(device_uuid):
    return reverse(
        "api:v1:client_data:client-devices-detail", kwargs={"uuid": str(device_uuid)}
    )


def test_create_device_via_api(factories, logged_in_api_client):
    device_uuid = uuid.uuid4()
    payload = {
        "uuid": str(device_uuid),
        "name": "Phone",
        "client_id": "tayra",
        "client_version": "1.2.3",
    }

    response = logged_in_api_client.post(_list_url(), payload, format="json")

    assert response.status_code == 201
    assert response.data["uuid"] == str(device_uuid)
    assert response.data["name"] == "Phone"
    assert response.data["client_id"] == "tayra"
    assert response.data["client_version"] == "1.2.3"
    assert response.data["is_active"] is True

    device = models.ClientDevice.objects.get()
    assert device.user == logged_in_api_client.user
    assert device.uuid == device_uuid


def test_upsert_refreshes_name_and_last_seen(factories, logged_in_api_client):
    device = factories["client_data.ClientDevice"](
        user=logged_in_api_client.user,
        name="Old name",
        client_id="tayra",
        client_version="1.0.0",
    )
    old_seen = device.last_seen_at
    payload = {
        "uuid": str(device.uuid),
        "name": "New name",
        "client_id": "tayra",
        "client_version": "2.0.0",
    }

    response = logged_in_api_client.post(_list_url(), payload, format="json")

    assert response.status_code == 200
    assert response.data["name"] == "New name"
    assert response.data["client_version"] == "2.0.0"
    assert models.ClientDevice.objects.count() == 1

    device.refresh_from_db()
    assert device.name == "New name"
    assert device.client_version == "2.0.0"
    assert device.last_seen_at >= old_seen
    assert device.is_active is True


def test_upsert_omitting_client_version_preserves_existing(
    factories, logged_in_api_client
):
    device = factories["client_data.ClientDevice"](
        user=logged_in_api_client.user,
        name="Phone",
        client_id="tayra",
        client_version="1.0.0",
    )
    payload = {
        "uuid": str(device.uuid),
        "name": "Phone renamed",
        "client_id": "tayra",
        # client_version intentionally omitted
    }

    response = logged_in_api_client.post(_list_url(), payload, format="json")

    assert response.status_code == 200
    assert response.data["name"] == "Phone renamed"
    assert response.data["client_version"] == "1.0.0"
    device.refresh_from_db()
    assert device.client_version == "1.0.0"
    assert device.name == "Phone renamed"


def test_list_own_devices_only(factories, logged_in_api_client):
    mine = factories["client_data.ClientDevice"](user=logged_in_api_client.user)
    factories["client_data.ClientDevice"]()  # other user

    response = logged_in_api_client.get(_list_url())

    assert response.status_code == 200
    assert response.data["count"] == 1
    assert response.data["results"][0]["uuid"] == str(mine.uuid)


def test_soft_delete_sets_inactive(factories, logged_in_api_client):
    device = factories["client_data.ClientDevice"](user=logged_in_api_client.user)

    response = logged_in_api_client.delete(_detail_url(device.uuid))

    assert response.status_code == 204
    assert models.ClientDevice.objects.count() == 1
    device.refresh_from_db()
    assert device.is_active is False


def test_post_reactivates_soft_deleted_device(factories, logged_in_api_client):
    device = factories["client_data.ClientDevice"](
        user=logged_in_api_client.user,
        name="Laptop",
        is_active=False,
    )
    payload = {
        "uuid": str(device.uuid),
        "name": "Laptop",
        "client_id": device.client_id,
        "client_version": "1.0.0",
    }

    response = logged_in_api_client.post(_list_url(), payload, format="json")

    assert response.status_code == 200
    assert response.data["is_active"] is True
    device.refresh_from_db()
    assert device.is_active is True


def test_patch_rename(factories, logged_in_api_client):
    device = factories["client_data.ClientDevice"](
        user=logged_in_api_client.user, name="Old"
    )

    response = logged_in_api_client.patch(
        _detail_url(device.uuid), {"name": "Renamed"}, format="json"
    )

    assert response.status_code == 200
    assert response.data["name"] == "Renamed"
    device.refresh_from_db()
    assert device.name == "Renamed"


def test_patch_set_is_active(factories, logged_in_api_client):
    device = factories["client_data.ClientDevice"](
        user=logged_in_api_client.user, is_active=True
    )

    response = logged_in_api_client.patch(
        _detail_url(device.uuid), {"is_active": False}, format="json"
    )

    assert response.status_code == 200
    assert response.data["is_active"] is False
    device.refresh_from_db()
    assert device.is_active is False


def test_put_not_allowed(factories, logged_in_api_client):
    device = factories["client_data.ClientDevice"](user=logged_in_api_client.user)

    response = logged_in_api_client.put(
        _detail_url(device.uuid),
        {"name": "full replace", "is_active": True},
        format="json",
    )

    assert response.status_code == 405


def test_cannot_access_other_users_device(factories, logged_in_api_client):
    other = factories["client_data.ClientDevice"]()

    # No RetrieveModelMixin: detail GET is not bound → 405 (not an existence oracle).
    response = logged_in_api_client.get(_detail_url(other.uuid))
    assert response.status_code == 405

    response = logged_in_api_client.patch(
        _detail_url(other.uuid), {"name": "hacked"}, format="json"
    )
    assert response.status_code == 404

    response = logged_in_api_client.delete(_detail_url(other.uuid))
    assert response.status_code == 404


def test_anonymous_denied(db, api_client, preferences):
    preferences["common__api_authentication_required"] = False
    response = api_client.get(_list_url())
    assert response.status_code in (401, 403)

    response = api_client.post(
        _list_url(),
        {
            "uuid": str(uuid.uuid4()),
            "name": "x",
            "client_id": "tayra",
        },
        format="json",
    )
    assert response.status_code in (401, 403)


def test_oauth_token_without_client_data_scope_denied(factories, api_client):
    """listenings-only tokens must not access client-devices (K10 scope separation)."""
    user = factories["users.User"]()
    scope = "read:listenings write:listenings"
    token = factories["users.AccessToken"](
        user=user,
        scope=scope,
        application__scope=scope,
    )

    response = api_client.get(
        _list_url(), HTTP_AUTHORIZATION=f"Bearer {token.token}"
    )
    assert response.status_code == 403

    response = api_client.post(
        _list_url(),
        {
            "uuid": str(uuid.uuid4()),
            "name": "Phone",
            "client_id": "tayra",
        },
        format="json",
        HTTP_AUTHORIZATION=f"Bearer {token.token}",
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

    response = api_client.get(
        _list_url(), HTTP_AUTHORIZATION=f"Bearer {token.token}"
    )
    assert response.status_code == 200

    device_uuid = uuid.uuid4()
    response = api_client.post(
        _list_url(),
        {
            "uuid": str(device_uuid),
            "name": "Phone",
            "client_id": "tayra",
        },
        format="json",
        HTTP_AUTHORIZATION=f"Bearer {token.token}",
    )
    assert response.status_code == 201
    assert models.ClientDevice.objects.filter(user=user, uuid=device_uuid).exists()


def test_lookup_by_uuid_not_pk(factories, logged_in_api_client):
    device = factories["client_data.ClientDevice"](user=logged_in_api_client.user)

    # Random UUID must not match (lookup is by device uuid, not integer pk)
    response = logged_in_api_client.patch(
        _detail_url(uuid.uuid4()), {"name": "nope"}, format="json"
    )
    assert response.status_code == 404

    response = logged_in_api_client.patch(
        _detail_url(device.uuid), {"name": "by-uuid"}, format="json"
    )
    assert response.status_code == 200
    assert response.data["name"] == "by-uuid"
