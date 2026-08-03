"""Tests for OIDC SSO configuration, flow, and token exchange."""

from __future__ import annotations

import re
import time
from unittest import mock

import pytest
from django.core.cache import cache
from django.urls import reverse

from funkwhale_api.users.oidc import client as oidc_client
from funkwhale_api.users.oidc import config as oidc_config
from funkwhale_api.users.oidc import redirects as oidc_redirects
from funkwhale_api.users.oidc import session as oidc_session
from funkwhale_api.users.oidc import users as oidc_users


DISCOVERY = {
    "issuer": "https://idp.example.com",
    "authorization_endpoint": "https://idp.example.com/auth",
    "token_endpoint": "https://idp.example.com/token",
    "userinfo_endpoint": "https://idp.example.com/userinfo",
    "jwks_uri": "https://idp.example.com/jwks",
}


@pytest.fixture(autouse=True)
def _clear_cache():
    cache.clear()
    yield
    cache.clear()


@pytest.fixture
def oidc_env(settings):
    settings.OIDC_ENABLED = True
    settings.OIDC_DISCOVERY_URL = "https://idp.example.com/.well-known/openid-configuration"
    settings.OIDC_CLIENT_ID = "tayra-client"
    settings.OIDC_CLIENT_SECRET = "super-secret"
    settings.OIDC_SCOPES = "openid profile email"
    settings.OIDC_USERNAME_CLAIM = "preferred_username"
    settings.OIDC_DISPLAY_NAME = "Company SSO"
    settings.OIDC_AUTO_CREATE = False
    # Align FUNKWHALE_URL with redirects used in tests (H3 allowlist).
    settings.FUNKWHALE_URL = "https://app.example.com"
    return settings


@pytest.mark.django_db
def test_auth_methods_disabled_by_default(api_client, settings):
    settings.OIDC_ENABLED = False
    settings.OIDC_DISCOVERY_URL = ""
    settings.OIDC_CLIENT_ID = ""
    settings.OIDC_CLIENT_SECRET = ""
    response = api_client.get(reverse("api:v1:users:auth_methods"))
    assert response.status_code == 200
    data = response.json()
    assert data["password"] is True
    assert data["oidc"]["enabled"] is False


@pytest.mark.django_db
def test_auth_methods_ready_from_env(api_client, oidc_env):
    response = api_client.get(reverse("api:v1:users:auth_methods"))
    assert response.status_code == 200
    data = response.json()
    assert data["oidc"]["enabled"] is True
    assert data["oidc"]["display_name"] == "Company SSO"
    assert data["oidc"]["login_path"] == "/api/v1/users/oidc/login/"
    # secrets must not leak
    assert "client_secret" not in data["oidc"]
    assert "client_id" not in data["oidc"]


@pytest.mark.django_db
def test_auth_methods_incomplete_config_reports_disabled(api_client, settings):
    settings.OIDC_ENABLED = True
    settings.OIDC_DISCOVERY_URL = "https://idp.example.com"
    settings.OIDC_CLIENT_ID = ""  # missing client id
    settings.OIDC_CLIENT_SECRET = "sec"
    response = api_client.get(reverse("api:v1:users:auth_methods"))
    assert response.json()["oidc"]["enabled"] is False


@pytest.mark.django_db
def test_oidc_login_redirects_to_idp(api_client, oidc_env):
    with mock.patch(
        "funkwhale_api.users.oidc.client.fetch_discovery",
        return_value=DISCOVERY,
    ):
        response = api_client.get(
            reverse("api:v1:users:oidc_login"),
            {
                "client_redirect": "https://app.example.com/auth/sso/callback",
                "state": "client-state-1",
            },
        )
    assert response.status_code in (302, 301)
    location = response["Location"]
    assert location.startswith("https://idp.example.com/auth")
    assert "client_id=tayra-client" in location
    assert "state=" in location
    assert "code_challenge=" in location
    assert "nonce=" in location
    # H3: transaction binding cookie set on login start.
    assert oidc_session.TX_COOKIE_NAME in response.cookies


@pytest.mark.django_db
def test_oidc_login_rejects_bad_redirect(api_client, oidc_env):
    response = api_client.get(
        reverse("api:v1:users:oidc_login"),
        {"client_redirect": "javascript:alert(1)"},
    )
    assert response.status_code == 400
    assert response.json()["error"] == "invalid_redirect"


@pytest.mark.django_db
def test_oidc_login_rejects_open_redirect(api_client, oidc_env):
    """H3: arbitrary https URLs are no longer accepted."""
    response = api_client.get(
        reverse("api:v1:users:oidc_login"),
        {"client_redirect": "https://evil.example/phish"},
    )
    assert response.status_code == 400
    assert response.json()["error"] == "invalid_redirect"


@pytest.mark.django_db
def test_oidc_login_allows_oob(api_client, oidc_env):
    with mock.patch(
        "funkwhale_api.users.oidc.client.fetch_discovery",
        return_value=DISCOVERY,
    ):
        response = api_client.get(
            reverse("api:v1:users:oidc_login"),
            {"client_redirect": "urn:ietf:wg:oauth:2.0:oob", "tx": "a" * 32},
        )
    assert response.status_code in (302, 301)


@pytest.mark.django_db
def test_oidc_login_allows_extra_origin(api_client, oidc_env, settings):
    settings.OIDC_CLIENT_REDIRECT_ORIGINS = ["https://spa.dev.example"]
    with mock.patch(
        "funkwhale_api.users.oidc.client.fetch_discovery",
        return_value=DISCOVERY,
    ):
        response = api_client.get(
            reverse("api:v1:users:oidc_login"),
            {"client_redirect": "https://spa.dev.example/auth/sso/callback"},
        )
    assert response.status_code in (302, 301)


@pytest.mark.django_db
def test_oidc_login_disabled(api_client, settings):
    settings.OIDC_ENABLED = False
    response = api_client.get(
        reverse("api:v1:users:oidc_login"),
        {"client_redirect": "urn:ietf:wg:oauth:2.0:oob"},
    )
    assert response.status_code == 404


@pytest.mark.django_db
def test_oidc_callback_happy_path_oob(api_client, oidc_env, factories):
    user = factories["users.User"](username="alice")
    user.set_password("unused")
    user.save()

    nonce = "test-nonce"
    code_verifier = "verifier"
    tx_binding = "tx-binding-test-value-32chars!!"
    state = oidc_session.store_login_state(
        client_redirect="urn:ietf:wg:oauth:2.0:oob",
        client_state="",
        nonce=nonce,
        code_verifier=code_verifier,
        tx_binding=tx_binding,
    )

    id_claims = {
        "iss": DISCOVERY["issuer"],
        "aud": "tayra-client",
        "sub": "alice-sub-1",
        "exp": int(time.time()) + 300,
        "iat": int(time.time()),
        "nonce": nonce,
        "preferred_username": "alice",
    }

    with mock.patch(
        "funkwhale_api.users.oidc.client.fetch_discovery",
        return_value=DISCOVERY,
    ), mock.patch(
        "funkwhale_api.users.oidc.client.exchange_code",
        return_value={"id_token": "fake.jwt.token", "access_token": "at"},
    ), mock.patch(
        "funkwhale_api.users.oidc.client.validate_id_token",
        return_value=id_claims,
    ):
        response = api_client.get(
            reverse("api:v1:users:oidc_callback"),
            {"code": "auth-code", "state": state},
        )

    assert response.status_code == 200
    assert b"Sign-in code" in response.content
    body = response.content.decode()
    assert 'id="code"' in body

    match = re.search(r'id="code">([^<]+)</code>', body)
    assert match
    exchange_code = match.group(1)

    # Stolen code without binding must fail (H3). Drop cookies so this
    # simulates an attacker who only observed the code (not the oidc_tx cookie).
    api_client.cookies.clear()
    stolen = api_client.post(
        reverse("api:v1:users:oidc_token"),
        {"code": exchange_code},
        format="json",
    )
    assert stolen.status_code == 400
    assert stolen.json()["error"] == "invalid_code"

    token_response = api_client.post(
        reverse("api:v1:users:oidc_token"),
        {"code": exchange_code, "tx": tx_binding},
        format="json",
    )
    assert token_response.status_code == 200, token_response.content
    data = token_response.json()
    assert data["access_token"]
    assert data["refresh_token"]
    assert data["token_type"] == "Bearer"
    assert data["listen_token"]

    # Code is single-use
    again = api_client.post(
        reverse("api:v1:users:oidc_token"),
        {"code": exchange_code, "tx": tx_binding},
        format="json",
    )
    assert again.status_code == 400
    assert again.json()["error"] == "invalid_code"


@pytest.mark.django_db
def test_oidc_callback_user_not_found(api_client, oidc_env, factories):
    nonce = "n"
    state = oidc_session.store_login_state(
        client_redirect="https://app.example.com/cb",
        client_state="s1",
        nonce=nonce,
        code_verifier="v",
        tx_binding="tx1",
    )
    with mock.patch(
        "funkwhale_api.users.oidc.client.fetch_discovery",
        return_value=DISCOVERY,
    ), mock.patch(
        "funkwhale_api.users.oidc.client.exchange_code",
        return_value={"id_token": "x"},
    ), mock.patch(
        "funkwhale_api.users.oidc.client.validate_id_token",
        return_value={
            "iss": DISCOVERY["issuer"],
            "sub": "unknown-sub",
            "preferred_username": "nobody",
            "nonce": nonce,
        },
    ):
        response = api_client.get(
            reverse("api:v1:users:oidc_callback"),
            {"code": "c", "state": state},
        )
    assert response.status_code in (302, 301)
    assert "error=user_not_found" in response["Location"]
    assert "state=s1" in response["Location"]


@pytest.mark.django_db
def test_oidc_callback_auto_create(api_client, oidc_env, factories, settings):
    settings.OIDC_AUTO_CREATE = True
    nonce = "n2"
    state = oidc_session.store_login_state(
        client_redirect="urn:ietf:wg:oauth:2.0:oob",
        client_state="",
        nonce=nonce,
        code_verifier="v",
        tx_binding="tx2",
    )
    with mock.patch(
        "funkwhale_api.users.oidc.client.fetch_discovery",
        return_value=DISCOVERY,
    ), mock.patch(
        "funkwhale_api.users.oidc.client.exchange_code",
        return_value={"id_token": "x"},
    ), mock.patch(
        "funkwhale_api.users.oidc.client.validate_id_token",
        return_value={
            "iss": DISCOVERY["issuer"],
            "sub": "newperson-sub",
            "preferred_username": "newperson",
            "email": "new@example.com",
            "name": "New Person",
            "nonce": nonce,
        },
    ):
        response = api_client.get(
            reverse("api:v1:users:oidc_callback"),
            {"code": "c", "state": state},
        )
    assert response.status_code == 200
    from django.contrib.auth import get_user_model

    from funkwhale_api.users.models import OidcIdentity

    User = get_user_model()
    user = User.objects.get(username="newperson")
    assert user.email == "new@example.com"
    assert not user.has_usable_password()
    assert user.actor_id is not None
    binding = OidcIdentity.objects.get(user=user)
    assert binding.subject == "newperson-sub"
    assert binding.issuer == DISCOVERY["issuer"]


@pytest.mark.django_db
def test_oidc_callback_inactive_user(api_client, oidc_env, factories):
    user = factories["users.User"](username="ghost", is_active=False)
    user.save()
    nonce = "n3"
    state = oidc_session.store_login_state(
        client_redirect="https://app.example.com/cb",
        client_state="",
        nonce=nonce,
        code_verifier="v",
        tx_binding="tx3",
    )
    with mock.patch(
        "funkwhale_api.users.oidc.client.fetch_discovery",
        return_value=DISCOVERY,
    ), mock.patch(
        "funkwhale_api.users.oidc.client.exchange_code",
        return_value={"id_token": "x"},
    ), mock.patch(
        "funkwhale_api.users.oidc.client.validate_id_token",
        return_value={
            "iss": DISCOVERY["issuer"],
            "sub": "ghost-sub",
            "preferred_username": "ghost",
            "nonce": nonce,
        },
    ):
        response = api_client.get(
            reverse("api:v1:users:oidc_callback"),
            {"code": "c", "state": state},
        )
    assert response.status_code in (302, 301)
    assert "error=inactive" in response["Location"]


@pytest.mark.django_db
def test_oidc_callback_invalid_state(api_client, oidc_env):
    response = api_client.get(
        reverse("api:v1:users:oidc_callback"),
        {"code": "c", "state": "nope"},
    )
    assert response.status_code == 400
    assert response.json()["error"] == "invalid_state"


def test_config_from_env_only(oidc_env):
    cfg = oidc_config.get_oidc_config()
    assert cfg["enabled"] is True
    assert cfg["ready"] is True
    assert cfg["display_name"] == "Company SSO"
    assert cfg["client_id"] == "tayra-client"
    assert cfg["auto_create"] is False


def test_config_env_disabled_is_not_ready(settings):
    """OIDC stays off when env is disabled (UI prefs no longer apply)."""
    settings.OIDC_ENABLED = False
    settings.OIDC_DISCOVERY_URL = "https://idp.example.com"
    settings.OIDC_CLIENT_ID = "cid"
    settings.OIDC_CLIENT_SECRET = "sec"
    settings.OIDC_DISPLAY_NAME = "Env Label"
    cfg = oidc_config.get_oidc_config()
    assert cfg["enabled"] is False
    assert cfg["ready"] is False
    assert cfg["display_name"] == "Env Label"


def test_normalize_discovery_url():
    assert (
        oidc_client.normalize_discovery_url("https://idp.example.com")
        == "https://idp.example.com/.well-known/openid-configuration"
    )
    full = "https://idp.example.com/.well-known/openid-configuration"
    assert oidc_client.normalize_discovery_url(full) == full


def test_extract_username():
    assert (
        oidc_client.extract_username(
            {"preferred_username": "bob"}, "preferred_username"
        )
        == "bob"
    )
    assert oidc_client.extract_username({}, "preferred_username") == ""


def test_redirect_allowlist_helpers(settings):
    settings.FUNKWHALE_URL = "https://music.example.org"
    assert oidc_redirects.is_allowed_client_redirect(
        "https://music.example.org/auth/sso/callback"
    )
    assert oidc_redirects.is_allowed_client_redirect(
        "urn:ietf:wg:oauth:2.0:oob"
    )
    assert oidc_redirects.is_allowed_client_redirect("tayra://sso/callback")
    assert not oidc_redirects.is_allowed_client_redirect(
        "https://evil.example/"
    )
    assert not oidc_redirects.is_allowed_client_redirect("javascript:alert(1)")


def _claims(sub="sub-1", iss="https://idp.example.com", **extra):
    data = {"iss": iss, "sub": sub}
    data.update(extra)
    return data


@pytest.mark.django_db
def test_resolve_user_first_time_username_link_creates_binding(factories):
    factories["users.User"](username="Sam")
    user, created = oidc_users.resolve_user(
        username="sam",
        claims=_claims(sub="idp-sam"),
        auto_create=False,
    )
    assert created is False
    assert user.username == "Sam"
    binding = user.oidc_identities.get()
    assert binding.issuer == "https://idp.example.com"
    assert binding.subject == "idp-sam"


@pytest.mark.django_db
def test_resolve_user_matches_by_sub_not_username(factories):
    """After binding, login uses (iss, sub) even if username claim changes."""
    local = factories["users.User"](username="alice")
    oidc_users.resolve_user(
        username="alice",
        claims=_claims(sub="stable-sub"),
        auto_create=False,
    )
    # Attacker-controlled or renamed claim must not matter.
    user, created = oidc_users.resolve_user(
        username="admin",
        claims=_claims(sub="stable-sub"),
        auto_create=False,
    )
    assert created is False
    assert user.pk == local.pk
    assert user.username == "alice"


@pytest.mark.django_db
def test_resolve_user_rejects_username_hijack_after_binding(factories):
    """A second IdP subject cannot bind to a user already linked for that issuer."""
    factories["users.User"](username="admin")
    oidc_users.resolve_user(
        username="admin",
        claims=_claims(sub="real-admin-sub"),
        auto_create=False,
    )
    with pytest.raises(oidc_users.OidcUserError) as exc:
        oidc_users.resolve_user(
            username="admin",
            claims=_claims(sub="attacker-sub"),
            auto_create=False,
        )
    assert exc.value.code == "username_conflict"


@pytest.mark.django_db
def test_resolve_user_missing_subject_rejected(factories):
    factories["users.User"](username="x")
    with pytest.raises(oidc_users.OidcUserError) as exc:
        oidc_users.resolve_user(
            username="x",
            claims={"iss": "https://idp.example.com"},
            auto_create=False,
        )
    assert exc.value.code == "missing_subject"


@pytest.mark.django_db
def test_resolve_user_not_found_without_auto_create(factories):
    with pytest.raises(oidc_users.OidcUserError) as exc:
        oidc_users.resolve_user(
            username="missing",
            claims=_claims(sub="nope"),
            auto_create=False,
        )
    assert exc.value.code == "user_not_found"


@pytest.mark.django_db
def test_resolve_user_auto_create_binds_subject(factories):
    user, created = oidc_users.resolve_user(
        username="newperson",
        claims=_claims(sub="new-sub", email="new@example.com", name="New Person"),
        auto_create=True,
    )
    assert created is True
    assert user.username == "newperson"
    assert user.email == "new@example.com"
    binding = user.oidc_identities.get()
    assert binding.subject == "new-sub"

    # Second login is not a create and still matches by sub.
    again, created2 = oidc_users.resolve_user(
        username="ignored-claim",
        claims=_claims(sub="new-sub"),
        auto_create=True,
    )
    assert created2 is False
    assert again.pk == user.pk
