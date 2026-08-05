"""Tests for TOTP 2FA: crypto helpers, setup/confirm/disable, and login challenge."""

from __future__ import annotations

import base64

import pytest
from django.urls import reverse

from funkwhale_api.users import models, totp
from funkwhale_api.users.password_transport import (
    compute_client_proof,
    transport_secret,
)


def _b64url_decode(s: str) -> bytes:
    pad = "=" * (-len(s) % 4)
    return base64.urlsafe_b64decode(s + pad)


def _step_up_proof(api_client, password: str, username: str) -> dict:
    """Authenticated SCRAM step-up proof for password-confirm endpoints (H2)."""
    challenge = api_client.post(
        reverse("api:v1:users:password_confirm_challenge"),
        {},
        format="json",
    )
    assert challenge.status_code == 200, challenge.content
    data = challenge.json()
    client_nonce = "step-up-cn"
    proof = compute_client_proof(
        transport_secret(password),
        salt=_b64url_decode(data["salt"]),
        iterations=int(data["iterations"]),
        username=username,
        client_nonce=client_nonce,
        server_nonce=data["server_nonce"],
    )
    return {
        "challenge_id": data["challenge_id"],
        "client_nonce": client_nonce,
        "client_proof": proof,
    }


def _login(api_client, username: str, password: str):
    """Challenge + SCRAM proof login (returns response)."""
    challenge = api_client.post(
        reverse("api:v1:users:token_login_challenge"),
        {"username": username},
        format="json",
    )
    assert challenge.status_code == 200, challenge.content
    data = challenge.json()
    client_nonce = "totp-cn"
    proof = compute_client_proof(
        transport_secret(password),
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


def _enable_totp(user, secret=None) -> str:
    from django.utils import timezone

    secret = secret or totp.generate_base32_secret()
    models.TotpDevice.objects.update_or_create(
        user=user,
        defaults={
            "secret": totp.protect_totp_secret(secret),
            "confirmed": True,
            "confirmed_at": timezone.now(),
            "last_used_step": None,
        },
    )
    return secret


@pytest.mark.django_db
def test_totp_verify_roundtrip():
    secret = totp.generate_base32_secret()
    code = totp.totp_at(secret)
    ok, step = totp.verify_totp(secret, code)
    assert ok
    assert step is not None
    # Replay same step rejected when last_used_step set
    ok2, _ = totp.verify_totp(secret, code, last_used_step=step)
    assert not ok2


@pytest.mark.django_db
def test_totp_secret_fernet_not_readable_without_key(settings):
    """enc2: payload must not yield the base32 secret via base64 alone (H1)."""
    secret = totp.generate_base32_secret()
    protected = totp.protect_totp_secret(secret)
    assert protected.startswith("enc2:")
    assert secret not in protected
    # Raw base64 of the Fernet token must not equal the plaintext secret.
    blob = protected[len("enc2:") :]
    assert secret.encode() not in blob.encode()
    assert totp.reveal_totp_secret(protected) == secret
    # Wrong SECRET_KEY cannot decrypt.
    settings.SECRET_KEY = "x" * 50
    assert totp.reveal_totp_secret(protected) == ""


@pytest.mark.django_db
def test_totp_secret_migrates_enc1_to_enc2(factories):
    from django.core import signing

    secret = totp.generate_base32_secret()
    legacy = "enc1:" + signing.dumps(secret, salt="tayra-totp-device-secret")
    assert totp.reveal_totp_secret(legacy) == secret
    upgraded = totp.protect_totp_secret(legacy)
    assert upgraded.startswith("enc2:")
    assert totp.reveal_totp_secret(upgraded) == secret


@pytest.mark.django_db
def test_token_login_requires_totp_when_enabled(api_client, factories):
    user = factories["users.User"](username="2fa-user")
    user.set_password("s3cret-pass")
    user.save()
    secret = _enable_totp(user)

    response = _login(api_client, "2fa-user", "s3cret-pass")
    assert response.status_code == 401, response.content
    data = response.json()
    assert data["error"] == "totp_required"
    assert data["mfa_token"]

    code = totp.totp_at(secret)
    complete = api_client.post(
        reverse("api:v1:users:token_login_2fa"),
        {"mfa_token": data["mfa_token"], "totp_code": code},
        format="json",
    )
    assert complete.status_code == 200, complete.content
    body = complete.json()
    assert body["access_token"]
    assert body["totp_enabled"] is True
    assert body["totp_setup_required"] is False

    # MFA challenge is single-use after success.
    again = api_client.post(
        reverse("api:v1:users:token_login_2fa"),
        {"mfa_token": data["mfa_token"], "totp_code": code},
        format="json",
    )
    assert again.status_code == 400
    assert again.json()["error"] == "invalid_mfa_token"


@pytest.mark.django_db
def test_token_login_2fa_rejects_bad_code(api_client, factories):
    user = factories["users.User"](username="2fa-bad")
    user.set_password("s3cret-pass")
    user.save()
    _enable_totp(user)

    challenge = _login(api_client, "2fa-bad", "s3cret-pass")
    assert challenge.status_code == 401
    mfa = challenge.json()["mfa_token"]

    bad = api_client.post(
        reverse("api:v1:users:token_login_2fa"),
        {"mfa_token": mfa, "totp_code": "000000"},
        format="json",
    )
    assert bad.status_code == 400
    assert bad.json()["error"] == "invalid_totp"


def test_recovery_code_hash_is_domain_separated():
    """New hashes differ from the pre-domain bare sha256; both still normalize."""
    code = "ABCD-EF01-2345-6789-ABCD-EF01-2345-6789"
    new_digest = totp.hash_recovery_code(code)
    legacy = totp._legacy_hash_recovery_code(code)
    assert new_digest != legacy
    assert len(new_digest) == 64
    # Same code with different grouping still hashes the same.
    assert totp.hash_recovery_code(code.replace("-", "")) == new_digest


def test_totp_secret_protect_reveal_roundtrip():
    secret = totp.generate_base32_secret()
    stored = totp.protect_totp_secret(secret)
    assert stored.startswith("enc1:")
    assert stored != secret
    assert totp.reveal_totp_secret(stored) == secret
    # Legacy plaintext still works.
    assert totp.reveal_totp_secret(secret) == secret
    # Idempotent protect.
    assert totp.protect_totp_secret(stored) == stored


def test_mfa_token_is_single_use(settings):
    from django.core.cache import cache

    cache.clear()
    token = totp.create_mfa_token(42)
    assert totp.load_mfa_token(token) == 42
    # Peek does not consume.
    assert totp.load_mfa_token(token) == 42
    assert totp.consume_mfa_token(token) == 42
    # Second consume / load fails.
    assert totp.consume_mfa_token(token) is None
    assert totp.load_mfa_token(token) is None


def test_generate_recovery_codes_have_high_entropy():
    codes = totp.generate_recovery_codes(count=3)
    assert len(codes) == 3
    for c in codes:
        normalized = totp.normalize_recovery_code(c)
        assert len(normalized) == 32  # 128 bits hex
        assert normalized.isalnum()


@pytest.mark.django_db
def test_token_login_2fa_recovery_code(api_client, factories):
    user = factories["users.User"](username="2fa-rec")
    user.set_password("s3cret-pass")
    user.save()
    _enable_totp(user)
    codes = totp.generate_recovery_codes(count=2)
    totp.store_recovery_codes(user, codes)

    challenge = _login(api_client, "2fa-rec", "s3cret-pass")
    mfa = challenge.json()["mfa_token"]

    ok = api_client.post(
        reverse("api:v1:users:token_login_2fa"),
        {"mfa_token": mfa, "totp_code": codes[0]},
        format="json",
    )
    assert ok.status_code == 200, ok.content
    assert ok.json()["access_token"]

    # Same recovery code cannot be reused
    challenge2 = _login(api_client, "2fa-rec", "s3cret-pass")
    mfa2 = challenge2.json()["mfa_token"]
    reuse = api_client.post(
        reverse("api:v1:users:token_login_2fa"),
        {"mfa_token": mfa2, "totp_code": codes[0]},
        format="json",
    )
    assert reuse.status_code == 400


@pytest.mark.django_db
def test_setup_confirm_disable_flow(logged_in_api_client, factories):
    user = logged_in_api_client.user
    user.set_password("s3cret-pass")
    user.save()

    setup = logged_in_api_client.post(reverse("api:v1:users:users-me-2fa-setup"))
    assert setup.status_code == 200, setup.content
    secret = setup.json()["secret"]
    assert setup.json()["otpauth_uri"].startswith("otpauth://totp/")

    code = totp.totp_at(secret)
    confirm = logged_in_api_client.post(
        reverse("api:v1:users:users-me-2fa-confirm"),
        {"code": code},
        format="json",
    )
    assert confirm.status_code == 200, confirm.content
    recovery = confirm.json()["recovery_codes"]
    assert len(recovery) == totp.RECOVERY_CODE_COUNT

    status = logged_in_api_client.get(reverse("api:v1:users:users-me-2fa"))
    assert status.status_code == 200
    assert status.json()["enabled"] is True

    me = logged_in_api_client.get(reverse("api:v1:users:users-me"))
    assert me.json()["totp_enabled"] is True
    assert me.json()["totp_required"] is False

    # Prefer a recovery code so we don't collide with confirm's last_used_step
    # within the same TOTP period.
    proof = _step_up_proof(logged_in_api_client, "s3cret-pass", user.username)
    disable = logged_in_api_client.post(
        reverse("api:v1:users:users-me-2fa-disable"),
        {**proof, "code": recovery[0]},
        format="json",
    )
    assert disable.status_code == 204, getattr(disable, "content", b"")
    assert not models.TotpDevice.objects.filter(user=user).exists()


@pytest.mark.django_db
def test_force_2fa_blocks_disable_and_flags_me(logged_in_api_client, factories, preferences):
    preferences["users__force_2fa"] = True
    user = logged_in_api_client.user
    user.set_password("s3cret-pass")
    user.save()
    secret = _enable_totp(user)

    me = logged_in_api_client.get(reverse("api:v1:users:users-me"))
    # Enabled already → not required
    assert me.json()["totp_enabled"] is True
    assert me.json()["totp_required"] is False

    # New password user without TOTP would need setup
    other = factories["users.User"](username="needs-2fa")
    other.set_password("x")
    other.save()
    assert totp.needs_totp_setup(other) is True

    proof = _step_up_proof(logged_in_api_client, "s3cret-pass", user.username)
    disable = logged_in_api_client.post(
        reverse("api:v1:users:users-me-2fa-disable"),
        {**proof, "code": totp.totp_at(secret)},
        format="json",
    )
    assert disable.status_code == 403
    assert disable.json()["error"] == "force_2fa"


@pytest.mark.django_db
def test_login_flags_totp_setup_required_when_forced(api_client, factories, preferences):
    preferences["users__force_2fa"] = True
    user = factories["users.User"](username="force-me")
    user.set_password("s3cret-pass")
    user.save()

    response = _login(api_client, "force-me", "s3cret-pass")
    assert response.status_code == 200, response.content
    data = response.json()
    assert data["access_token"]
    assert data["totp_setup_required"] is True
    assert data["totp_enabled"] is False


@pytest.mark.django_db
def test_sso_only_user_skips_force_2fa(factories, preferences):
    preferences["users__force_2fa"] = True
    user = factories["users.User"](username="sso-only")
    user.set_unusable_password()
    user.save()
    assert totp.needs_totp_setup(user) is False
    assert totp.is_password_user(user) is False


@pytest.mark.django_db
def test_token_login_without_2fa_unchanged(api_client, factories):
    user = factories["users.User"](username="plain")
    user.set_password("s3cret-pass")
    user.save()
    response = _login(api_client, "plain", "s3cret-pass")
    assert response.status_code == 200
    data = response.json()
    assert data["access_token"]
    assert data.get("totp_enabled") is False
    assert data.get("totp_setup_required") is False
