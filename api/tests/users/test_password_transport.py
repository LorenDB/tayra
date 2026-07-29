import pytest

from funkwhale_api.users.password_transport import (
    hash_password_for_transport,
    is_transport_password_hash,
)


def test_hash_password_for_transport_is_stable_hex():
    digest = hash_password_for_transport("s3cret-pass")
    assert digest == hash_password_for_transport("s3cret-pass")
    assert is_transport_password_hash(digest)
    # Different passwords (or empty) must not collide with the sample.
    assert digest != hash_password_for_transport("other")
    assert digest != hash_password_for_transport("")


def test_hash_is_not_raw_sha256_of_password():
    """Domain separation: must not equal bare SHA-256(password)."""
    import hashlib

    bare = hashlib.sha256(b"s3cret-pass").hexdigest()
    assert hash_password_for_transport("s3cret-pass") != bare


def test_is_transport_password_hash_rejects_plaintext():
    assert not is_transport_password_hash("s3cret-pass")
    assert not is_transport_password_hash("A" * 64)  # uppercase
    assert not is_transport_password_hash("0" * 63)
    assert not is_transport_password_hash("0" * 65)
    assert not is_transport_password_hash("")


@pytest.mark.django_db
def test_set_password_stores_transport_digest(factories):
    user = factories["users.User"]()
    user.set_password("s3cret-pass")
    user.save()

    transport = hash_password_for_transport("s3cret-pass")
    # Plaintext still verifies (admin/CLI).
    assert user.check_password("s3cret-pass")
    # Transport digest verifies (token login).
    assert user.check_password(transport)
    assert not user.check_password("wrong")
