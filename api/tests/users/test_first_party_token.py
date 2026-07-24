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
    assert data["client_secret"]
    assert data["listen_token"]
    assert data["expires_in"] > 0


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
    token = login.json()["access_token"]

    me = api_client.get(
        reverse("api:v1:users:users-me"),
        HTTP_AUTHORIZATION=f"Bearer {token}",
    )
    assert me.status_code == 200
    assert me.json()["username"] == "carol"
