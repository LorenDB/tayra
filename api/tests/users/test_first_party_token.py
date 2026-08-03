import base64
import json

import pytest
from django.urls import reverse

from funkwhale_api.users.password_transport import (
    compute_client_proof,
    transport_secret,
)


def _b64url_decode(s: str) -> bytes:
    pad = "=" * (-len(s) % 4)
    return base64.urlsafe_b64decode(s + pad)


def _login_via_challenge(api_client, username: str, password: str):
    """Complete challenge + proof login; return the token response."""
    challenge = api_client.post(
        reverse("api:v1:users:token_login_challenge"),
        {"username": username},
        format="json",
    )
    assert challenge.status_code == 200, challenge.content
    data = challenge.json()
    assert data["scheme"] == "scram_v2"

    secret = transport_secret(password)
    client_nonce = "test-client-nonce"
    proof = compute_client_proof(
        secret,
        salt=_b64url_decode(data["salt"]),
        iterations=int(data["iterations"]),
        username=username,
        client_nonce=client_nonce,
        server_nonce=data["server_nonce"],
    )
    return api_client.post(
        reverse("api:v1:users:token_login"),
        {
            "username": username,
            "challenge_id": data["challenge_id"],
            "client_nonce": client_nonce,
            "client_proof": proof,
        },
        format="json",
    )


@pytest.mark.django_db
def test_token_login_returns_oauth_tokens(api_client, factories):
    user = factories["users.User"](username="alice")
    user.set_password("s3cret-pass")
    user.save()

    response = _login_via_challenge(api_client, "alice", "s3cret-pass")

    assert response.status_code == 200, response.content
    data = response.json()
    assert data["token_type"] == "Bearer"
    # Leaf scopes for the user (not the parent "read write" string).
    scope_parts = set(data["scope"].split())
    assert "read:profile" in scope_parts
    assert "write:libraries" in scope_parts
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

    response = _login_via_challenge(api_client, "dave@example.com", "s3cret-pass")
    assert response.status_code == 200, response.content
    assert response.json()["access_token"]


@pytest.mark.django_db
def test_token_login_rejects_bad_password(api_client, factories):
    user = factories["users.User"](username="bob")
    user.set_password("right")
    user.save()

    response = _login_via_challenge(api_client, "bob", "wrong")
    assert response.status_code == 400
    assert response.json()["error"] == "invalid_credentials"


@pytest.mark.django_db
def test_token_login_rejects_plaintext_password(api_client, factories):
    user = factories["users.User"](username="plain")
    user.set_password("s3cret-pass")
    user.save()

    challenge = api_client.post(
        reverse("api:v1:users:token_login_challenge"),
        {"username": "plain"},
        format="json",
    ).json()

    # Plaintext in password field with a SCRAM challenge is not a valid proof.
    response = api_client.post(
        reverse("api:v1:users:token_login"),
        {
            "username": "plain",
            "challenge_id": challenge["challenge_id"],
            "password": "s3cret-pass",
            "client_nonce": "x",
            "client_proof": "0" * 64,
        },
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

    challenge = api_client.post(
        reverse("api:v1:users:token_login_challenge"),
        data=json.dumps({"username": "rawjson"}),
        content_type="application/json",
    )
    assert challenge.status_code == 200, challenge.content
    data = challenge.json()
    secret = transport_secret("s3cret-pass")
    client_nonce = "raw-cn"
    proof = compute_client_proof(
        secret,
        salt=_b64url_decode(data["salt"]),
        iterations=int(data["iterations"]),
        username="rawjson",
        client_nonce=client_nonce,
        server_nonce=data["server_nonce"],
    )
    response = api_client.post(
        reverse("api:v1:users:token_login"),
        data=json.dumps(
            {
                "username": "rawjson",
                "challenge_id": data["challenge_id"],
                "client_nonce": client_nonce,
                "client_proof": proof,
            }
        ),
        content_type="application/json",
    )
    assert response.status_code == 200, response.content
    assert response.json()["access_token"]


@pytest.mark.django_db
def test_token_login_access_token_authenticates(api_client, factories):
    user = factories["users.User"](username="carol")
    user.set_password("s3cret-pass")
    user.save()

    login = _login_via_challenge(api_client, "carol", "s3cret-pass")
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

    login = _login_via_challenge(api_client, "erin", "s3cret-pass")
    assert login.status_code == 200, login.content
    data = login.json()

    # Second login reuses the same Application (must still succeed).
    login2 = _login_via_challenge(api_client, "erin", "s3cret-pass")
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
