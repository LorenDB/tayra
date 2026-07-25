import json

import pytest
from django.urls import reverse


@pytest.mark.django_db
def test_token_login_returns_oauth_tokens(api_client, factories):
    user = factories["users.User"](username="alice")
    user.set_password("s3cret-pass")
    user.save()

    url = reverse("api:v1:users:token_login")
    response = api_client.post(
        url,
        {"username": "alice", "password": "s3cret-pass"},
        format="json",
    )

    assert response.status_code == 200, response.content
    data = response.json()
    assert data["token_type"] == "Bearer"
    assert data["scope"] == "read write"
    assert data["access_token"]
    assert data["refresh_token"]
    assert data["client_id"]
    # Public first-party client: secret is empty (DOT hashes secrets on save,
    # and a shared confidential secret cannot be recovered after create).
    assert data.get("client_secret") in (None, "")
    assert data["listen_token"]
    assert data["expires_in"] > 0


@pytest.mark.django_db
def test_token_login_by_email(api_client, factories):
    user = factories["users.User"](username="dave", email="dave@example.com")
    user.set_password("s3cret-pass")
    user.save()

    response = api_client.post(
        reverse("api:v1:users:token_login"),
        {"username": "dave@example.com", "password": "s3cret-pass"},
        format="json",
    )
    assert response.status_code == 200, response.content
    assert response.json()["access_token"]


@pytest.mark.django_db
def test_token_login_rejects_bad_password(api_client, factories):
    user = factories["users.User"](username="bob")
    user.set_password("right")
    user.save()

    url = reverse("api:v1:users:token_login")
    response = api_client.post(
        url,
        {"username": "bob", "password": "wrong"},
        format="json",
    )
    assert response.status_code == 400
    assert response.json()["error"] == "invalid_credentials"


@pytest.mark.django_db
def test_token_login_accepts_raw_json_body(api_client, factories):
    """SPA clients may hit the view with a raw JSON body (not multipart)."""
    user = factories["users.User"](username="rawjson")
    user.set_password("s3cret-pass")
    user.save()

    response = api_client.post(
        reverse("api:v1:users:token_login"),
        data=json.dumps({"username": "rawjson", "password": "s3cret-pass"}),
        content_type="application/json",
    )
    assert response.status_code == 200, response.content
    assert response.json()["access_token"]


@pytest.mark.django_db
def test_token_login_access_token_authenticates(api_client, factories):
    user = factories["users.User"](username="carol")
    user.set_password("s3cret-pass")
    user.save()

    login = api_client.post(
        reverse("api:v1:users:token_login"),
        {"username": "carol", "password": "s3cret-pass"},
        format="json",
    )
    assert login.status_code == 200, login.content
    token = login.json()["access_token"]

    me = api_client.get(
        reverse("api:v1:users:users-me"),
        HTTP_AUTHORIZATION=f"Bearer {token}",
    )
    assert me.status_code == 200
    assert me.json()["username"] == "carol"


@pytest.mark.django_db
def test_token_login_refresh_works_without_client_secret(api_client, factories):
    """First-party app is public; refresh must not require a hashed secret."""
    user = factories["users.User"](username="erin")
    user.set_password("s3cret-pass")
    user.save()

    login = api_client.post(
        reverse("api:v1:users:token_login"),
        {"username": "erin", "password": "s3cret-pass"},
        format="json",
    )
    assert login.status_code == 200, login.content
    data = login.json()

    # Second login reuses the same Application (must still succeed).
    login2 = api_client.post(
        reverse("api:v1:users:token_login"),
        {"username": "erin", "password": "s3cret-pass"},
        format="json",
    )
    assert login2.status_code == 200, login2.content

    refresh = api_client.post(
        reverse("api:v1:oauth:token"),
        {
            "grant_type": "refresh_token",
            "refresh_token": data["refresh_token"],
            "client_id": data["client_id"],
        },
    )
    assert refresh.status_code == 200, refresh.content
    assert refresh.json()["access_token"]
