import hashlib
import hmac

import pytest
from django.core.cache import cache
from django.urls import reverse

from funkwhale_api.users.password_transport import (
    compute_client_proof,
    create_scram_hash,
    get_instance_binding,
    hash_password_for_transport,
    is_scram_hash,
    is_transport_password_hash,
    parse_scram_hash,
    transport_secret,
    verify_client_proof,
    verify_scram_secret,
)


@pytest.fixture(autouse=True)
def _clear_cache():
    cache.clear()
    yield
    cache.clear()


def test_legacy_hash_password_for_transport_is_stable_hex():
    digest = hash_password_for_transport("s3cret-pass")
    assert digest == hash_password_for_transport("s3cret-pass")
    assert is_transport_password_hash(digest)
    assert digest != hash_password_for_transport("other")
    assert digest != hash_password_for_transport("")


def test_legacy_hash_is_not_raw_sha256_of_password():
    bare = hashlib.sha256(b"s3cret-pass").hexdigest()
    assert hash_password_for_transport("s3cret-pass") != bare


def test_is_transport_password_hash_rejects_plaintext():
    assert not is_transport_password_hash("s3cret-pass")
    assert not is_transport_password_hash("A" * 64)  # uppercase
    assert not is_transport_password_hash("0" * 63)
    assert not is_transport_password_hash("0" * 65)
    assert not is_transport_password_hash("")


def test_transport_secret_is_instance_bound():
    a = transport_secret("s3cret-pass")
    assert len(a) == 32
    # Stable for same password + instance.
    assert a == transport_secret("s3cret-pass")
    assert a != transport_secret("other")


def test_scram_roundtrip_plaintext_secret():
    encoded = create_scram_hash("s3cret-pass")
    assert is_scram_hash(encoded)
    assert verify_scram_secret(encoded, transport_secret("s3cret-pass"))
    assert not verify_scram_secret(encoded, transport_secret("wrong"))


def test_client_proof_roundtrip():
    password = "s3cret-pass"
    encoded = create_scram_hash(password)
    parsed = parse_scram_hash(encoded)
    assert parsed is not None
    secret = transport_secret(password)
    client_nonce = "client-nonce-1"
    server_nonce = "server-nonce-1"
    proof = compute_client_proof(
        secret,
        salt=parsed["salt"],
        iterations=parsed["iterations"],
        username="alice",
        client_nonce=client_nonce,
        server_nonce=server_nonce,
    )
    assert verify_client_proof(
        encoded,
        username="alice",
        client_nonce=client_nonce,
        server_nonce=server_nonce,
        client_proof_hex=proof,
    )
    # Wrong nonce must fail.
    assert not verify_client_proof(
        encoded,
        username="alice",
        client_nonce=client_nonce,
        server_nonce="other",
        client_proof_hex=proof,
    )


@pytest.mark.django_db
def test_set_password_stores_scram(factories):
    user = factories["users.User"]()
    user.set_password("s3cret-pass")
    user.save()

    assert is_scram_hash(user.password)
    assert user.check_password("s3cret-pass")
    assert not user.check_password("wrong")
    # Hex transport secret also verifies (password confirmation wire form).
    assert user.check_password(transport_secret("s3cret-pass").hex())


@pytest.mark.django_db
def test_legacy_check_password_still_works(factories):
    """Pre-SCRAM rows: django_hash(v1_digest)."""
    from django.contrib.auth.hashers import make_password

    user = factories["users.User"]()
    digest = hash_password_for_transport("s3cret-pass")
    user.password = make_password(digest)
    user.save(update_fields=["password"])

    assert not is_scram_hash(user.password)
    assert user.check_password("s3cret-pass")
    assert user.check_password(digest)
    assert not user.check_password("wrong")


@pytest.mark.django_db
def test_token_login_scram_challenge_flow(api_client, factories):
    user = factories["users.User"](username="alice")
    user.set_password("s3cret-pass")
    user.save()

    challenge_url = reverse("api:v1:users:token_login_challenge")
    challenge = api_client.post(
        challenge_url, {"username": "alice"}, format="json"
    )
    assert challenge.status_code == 200, challenge.content
    data = challenge.json()
    assert data["scheme"] == "scram_v2"
    assert data["challenge_id"]
    assert data["server_nonce"]
    assert data["salt"]
    assert data["instance_binding"] == get_instance_binding().hex()
    assert data["transport_iterations"] >= 1

    secret = transport_secret("s3cret-pass")
    import base64

    def b64url_decode(s: str) -> bytes:
        pad = "=" * (-len(s) % 4)
        return base64.urlsafe_b64decode(s + pad)

    salt = b64url_decode(data["salt"])
    client_nonce = "cn1"
    proof = compute_client_proof(
        secret,
        salt=salt,
        iterations=int(data["iterations"]),
        username="alice",
        client_nonce=client_nonce,
        server_nonce=data["server_nonce"],
    )

    login = api_client.post(
        reverse("api:v1:users:token_login"),
        {
            "username": "alice",
            "challenge_id": data["challenge_id"],
            "client_nonce": client_nonce,
            "client_proof": proof,
        },
        format="json",
    )
    assert login.status_code == 200, login.content
    body = login.json()
    assert body["access_token"]
    assert body["refresh_token"]

    # Challenge is single-use.
    again = api_client.post(
        reverse("api:v1:users:token_login"),
        {
            "username": "alice",
            "challenge_id": data["challenge_id"],
            "client_nonce": client_nonce,
            "client_proof": proof,
        },
        format="json",
    )
    assert again.status_code == 400
    assert again.json()["error"] == "invalid_challenge"


@pytest.mark.django_db
def test_token_login_rejects_static_digest_without_challenge(api_client, factories):
    user = factories["users.User"](username="bob")
    user.set_password("s3cret-pass")
    user.save()

    response = api_client.post(
        reverse("api:v1:users:token_login"),
        {
            "username": "bob",
            "password": hash_password_for_transport("s3cret-pass"),
        },
        format="json",
    )
    assert response.status_code == 400
    assert response.json()["error"] == "missing_challenge"


@pytest.mark.django_db
def test_token_login_proof_not_replayable_across_challenges(api_client, factories):
    user = factories["users.User"](username="carol")
    user.set_password("s3cret-pass")
    user.save()

    def _challenge():
        return api_client.post(
            reverse("api:v1:users:token_login_challenge"),
            {"username": "carol"},
            format="json",
        ).json()

    c1 = _challenge()
    import base64

    def b64url_decode(s: str) -> bytes:
        pad = "=" * (-len(s) % 4)
        return base64.urlsafe_b64decode(s + pad)

    secret = transport_secret("s3cret-pass")
    proof = compute_client_proof(
        secret,
        salt=b64url_decode(c1["salt"]),
        iterations=int(c1["iterations"]),
        username="carol",
        client_nonce="cn",
        server_nonce=c1["server_nonce"],
    )

    # Use proof with a *different* challenge id → fail (consumed/mismatch).
    c2 = _challenge()
    bad = api_client.post(
        reverse("api:v1:users:token_login"),
        {
            "username": "carol",
            "challenge_id": c2["challenge_id"],
            "client_nonce": "cn",
            "client_proof": proof,  # bound to c1 server_nonce
        },
        format="json",
    )
    assert bad.status_code == 400
    assert bad.json()["error"] == "invalid_credentials"


@pytest.mark.django_db
def test_legacy_v1_login_with_challenge(api_client, factories):
    from django.contrib.auth.hashers import make_password

    user = factories["users.User"](username="legacy")
    digest = hash_password_for_transport("s3cret-pass")
    user.password = make_password(digest)
    user.save(update_fields=["password"])

    challenge = api_client.post(
        reverse("api:v1:users:token_login_challenge"),
        {"username": "legacy"},
        format="json",
    ).json()
    assert challenge["scheme"] == "legacy_v1"

    login = api_client.post(
        reverse("api:v1:users:token_login"),
        {
            "username": "legacy",
            "challenge_id": challenge["challenge_id"],
            "password": digest,
        },
        format="json",
    )
    assert login.status_code == 200, login.content
    assert login.json()["access_token"]
