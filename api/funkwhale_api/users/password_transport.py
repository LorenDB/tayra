"""Client → server password transport for first-party login.

H2 remediation: the previous static SHA-256 digest was a reusable, unsalted,
cross-instance password-equivalent. Login now uses a **salted per-request
verifier** (SCRAM-like proof over an instance-bound PBKDF2 secret).

Storage
-------
``set_password`` stores a compact SCRAM verifier string (fits Django's
128-char ``password`` field)::

    tayra_scram$<iterations>$<salt_b64>$<stored_key_b64>

derived from ``transport_secret(password)`` = PBKDF2-HMAC-SHA256 of the
account password with an instance-bound salt (not a bare SHA-256).

Login
-----
1. Client fetches a one-time challenge (nonce + user salt).
2. Client proves knowledge of ``transport_secret(password)`` via an HMAC
   proof bound to that nonce — the stable secret never goes on the wire.
3. Stolen proofs cannot be replayed (nonce is single-use).

Legacy rows (``django_hash(sha256(prefix+password))``) still verify for
admin/CLI and for a one-shot digest login that upgrades storage to SCRAM.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import re
import secrets
from typing import Any, Dict, Optional

from django.conf import settings
from django.core.cache import cache

# ── Constants ────────────────────────────────────────────────────────────

# Domain separation for the instance-bound transport secret (v2).
_DOMAIN_V2 = b"tayra-login-v2\0"

# Legacy v1 static digest (migration only).
_DOMAIN_V1 = b"tayra-login-v1\0"

# SCRAM-style labels (RFC 5802). ServerKey is omitted from storage (we only
# need StoredKey for client-proof verification; keeps the string ≤128 chars).
_CLIENT_KEY_LABEL = b"Client Key"

# PBKDF2 parameters for transport_secret / SCRAM salted password.
# Production uses a high iteration count; tests set WEAK_PASSWORDS=True.
_PRODUCTION_ITERATIONS = 210_000
_WEAK_ITERATIONS = 1_000
_SALT_LEN = 16
_KEY_LEN = 32


def _iterations() -> int:
    if getattr(settings, "WEAK_PASSWORDS", False):
        return _WEAK_ITERATIONS
    return _PRODUCTION_ITERATIONS


# Public aliases (resolved at call time via _iterations() for test overrides).
TRANSPORT_ITERATIONS = _PRODUCTION_ITERATIONS
SCRAM_ITERATIONS = _PRODUCTION_ITERATIONS

# Storage prefix for SCRAM verifiers.
SCRAM_PREFIX = "tayra_scram$"

# Challenge cache.
_CHALLENGE_PREFIX = "login:challenge:"
CHALLENGE_TTL = 120  # seconds

# Lowercase hex SHA-256 (legacy wire digest).
TRANSPORT_HASH_RE = re.compile(r"\A[0-9a-f]{64}\Z")

# Login proof: lowercase hex of 32-byte ClientProof.
CLIENT_PROOF_RE = re.compile(r"\A[0-9a-f]{64}\Z")


# ── Instance binding ─────────────────────────────────────────────────────


def get_instance_binding() -> bytes:
    """Public 16-byte instance id mixed into the transport KDF salt.

    Derived from ``FUNKWHALE_URL`` so digests/secrets do not transfer across
    pods. Safe to advertise to clients (not a secret).
    """
    url = (getattr(settings, "FUNKWHALE_URL", "") or "").strip().lower().rstrip("/")
    return hashlib.sha256(b"tayra-instance\0" + url.encode("utf-8")).digest()[:16]


def get_instance_binding_hex() -> str:
    return get_instance_binding().hex()


# ── Transport secret (stable, never sent for v2 login) ───────────────────


def transport_secret(password: str) -> bytes:
    """Instance-bound PBKDF2 secret derived from the account password."""
    if not isinstance(password, str):
        raise TypeError("password must be str")
    salt = _DOMAIN_V2 + get_instance_binding()
    return hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt,
        _iterations(),
        dklen=_KEY_LEN,
    )


def transport_secret_hex(password: str) -> str:
    """Hex form of :func:`transport_secret` (password-confirmation wire form)."""
    return transport_secret(password).hex()


# ── Legacy v1 digest (migration) ─────────────────────────────────────────


def hash_password_for_transport(password: str) -> str:
    """Legacy v1 static digest. Kept for migration and older clients.

    New login must use the challenge/proof flow. Password-confirmation
    endpoints may still accept this form via :meth:`User.check_password`.
    """
    if not isinstance(password, str):
        raise TypeError("password must be str")
    return hashlib.sha256(_DOMAIN_V1 + password.encode("utf-8")).hexdigest()


def is_transport_password_hash(value: str) -> bool:
    """True if ``value`` looks like a legacy 64-char hex digest."""
    return isinstance(value, str) and bool(TRANSPORT_HASH_RE.fullmatch(value))


# ── SCRAM storage ────────────────────────────────────────────────────────


def _b64encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode("ascii").rstrip("=")


def _b64decode(data: str) -> bytes:
    pad = "=" * (-len(data) % 4)
    return base64.urlsafe_b64decode(data + pad)


def is_scram_hash(encoded: str) -> bool:
    return isinstance(encoded, str) and encoded.startswith(SCRAM_PREFIX)


def create_scram_hash(password: str) -> str:
    """Build a SCRAM verifier string from the account password."""
    return create_scram_hash_from_secret(transport_secret(password))


def create_scram_hash_from_secret(
    secret: bytes, iterations: Optional[int] = None
) -> str:
    """Build SCRAM verifier from a raw secret (password-derived or legacy)."""
    if not isinstance(secret, (bytes, bytearray)):
        raise TypeError("secret must be bytes")
    if iterations is None:
        iterations = _iterations()
    salt = secrets.token_bytes(_SALT_LEN)
    salted = hashlib.pbkdf2_hmac("sha256", secret, salt, iterations, dklen=_KEY_LEN)
    client_key = hmac.new(salted, _CLIENT_KEY_LABEL, hashlib.sha256).digest()
    stored_key = hashlib.sha256(client_key).digest()
    encoded = (
        f"{SCRAM_PREFIX}{iterations}$"
        f"{_b64encode(salt)}${_b64encode(stored_key)}"
    )
    if len(encoded) > 128:
        # Django AbstractBaseUser.password is varchar(128).
        raise ValueError("SCRAM verifier exceeds password field length")
    return encoded


def parse_scram_hash(encoded: str) -> Optional[Dict[str, Any]]:
    """Parse SCRAM storage; return None if malformed."""
    if not is_scram_hash(encoded):
        return None
    parts = encoded.split("$")
    # tayra_scram$iter$salt$stored_key  (4 parts after split on "$")
    # Also accept legacy 5-part form that included server_key.
    if len(parts) not in (4, 5):
        return None
    try:
        iterations = int(parts[1])
        salt = _b64decode(parts[2])
        stored_key = _b64decode(parts[3])
    except (ValueError, TypeError):
        return None
    if iterations < 1 or len(salt) < 8 or len(stored_key) != _KEY_LEN:
        return None
    return {
        "iterations": iterations,
        "salt": salt,
        "stored_key": stored_key,
    }


def verify_scram_secret(encoded: str, secret: bytes) -> bool:
    """Constant-time verify that ``secret`` matches a SCRAM verifier."""
    parsed = parse_scram_hash(encoded)
    if parsed is None or not isinstance(secret, (bytes, bytearray)):
        return False
    salted = hashlib.pbkdf2_hmac(
        "sha256",
        bytes(secret),
        parsed["salt"],
        parsed["iterations"],
        dklen=_KEY_LEN,
    )
    client_key = hmac.new(salted, _CLIENT_KEY_LABEL, hashlib.sha256).digest()
    stored_key = hashlib.sha256(client_key).digest()
    return hmac.compare_digest(stored_key, parsed["stored_key"])


def _auth_message(username: str, client_nonce: str, server_nonce: str) -> bytes:
    # Simplified SCRAM AuthMessage (not full RFC GS2 header — first-party only).
    return (
        f"n={username},r={client_nonce},s={server_nonce}".encode("utf-8")
    )


def compute_client_proof(
    secret: bytes,
    *,
    salt: bytes,
    iterations: int,
    username: str,
    client_nonce: str,
    server_nonce: str,
) -> str:
    """Return hex ClientProof for the given secret and challenge."""
    salted = hashlib.pbkdf2_hmac(
        "sha256", secret, salt, iterations, dklen=_KEY_LEN
    )
    client_key = hmac.new(salted, _CLIENT_KEY_LABEL, hashlib.sha256).digest()
    stored_key = hashlib.sha256(client_key).digest()
    auth_msg = _auth_message(username, client_nonce, server_nonce)
    client_signature = hmac.new(stored_key, auth_msg, hashlib.sha256).digest()
    client_proof = bytes(a ^ b for a, b in zip(client_key, client_signature))
    return client_proof.hex()


def verify_client_proof(
    encoded: str,
    *,
    username: str,
    client_nonce: str,
    server_nonce: str,
    client_proof_hex: str,
) -> bool:
    """Verify a ClientProof against stored SCRAM verifier."""
    parsed = parse_scram_hash(encoded)
    if parsed is None:
        return False
    if not CLIENT_PROOF_RE.fullmatch(client_proof_hex or ""):
        return False
    try:
        client_proof = bytes.fromhex(client_proof_hex)
    except ValueError:
        return False
    if len(client_proof) != _KEY_LEN:
        return False

    auth_msg = _auth_message(username, client_nonce, server_nonce)
    client_signature = hmac.new(
        parsed["stored_key"], auth_msg, hashlib.sha256
    ).digest()
    client_key = bytes(a ^ b for a, b in zip(client_proof, client_signature))
    stored_key = hashlib.sha256(client_key).digest()
    return hmac.compare_digest(stored_key, parsed["stored_key"])


def scram_public_params(encoded: str) -> Optional[Dict[str, Any]]:
    """Salt + iterations for a SCRAM hash (safe to send to the client)."""
    parsed = parse_scram_hash(encoded)
    if parsed is None:
        return None
    return {
        "salt": _b64encode(parsed["salt"]),
        "iterations": parsed["iterations"],
    }


# ── Login challenges ─────────────────────────────────────────────────────


def _fake_scram_params(username: str) -> Dict[str, Any]:
    """Deterministic fake salt for unknown users (anti-enumeration)."""
    key = (getattr(settings, "SECRET_KEY", "") or "tayra").encode("utf-8")
    salt = hmac.new(
        key, f"login-fake-salt:{username.lower()}".encode("utf-8"), hashlib.sha256
    ).digest()[:_SALT_LEN]
    return {"salt": _b64encode(salt), "iterations": _iterations()}


def create_login_challenge(username: str, user=None) -> Dict[str, Any]:
    """Mint a one-time login challenge for ``username``.

    Returns a public dict the client needs to build a proof. Always succeeds
    with plausible parameters even when the user is missing (no enumeration).
    """
    username = (username or "").strip()
    challenge_id = secrets.token_urlsafe(32)
    server_nonce = secrets.token_urlsafe(24)

    scheme = "scram_v2"
    salt_b64 = None
    iterations = _iterations()
    legacy = False

    if user is not None and getattr(user, "is_active", True):
        encoded = getattr(user, "password", "") or ""
        if is_scram_hash(encoded):
            params = scram_public_params(encoded)
            if params:
                salt_b64 = params["salt"]
                iterations = params["iterations"]
        else:
            # Legacy django_hash(v1_digest) rows — one-shot digest login.
            scheme = "legacy_v1"
            legacy = True
    else:
        fake = _fake_scram_params(username or "anonymous")
        salt_b64 = fake["salt"]
        iterations = fake["iterations"]

    if salt_b64 is None and not legacy:
        fake = _fake_scram_params(username or "anonymous")
        salt_b64 = fake["salt"]
        iterations = fake["iterations"]

    payload = {
        "username": username,
        "server_nonce": server_nonce,
        "scheme": scheme,
        "user_id": getattr(user, "pk", None) if user is not None else None,
    }
    cache.set(f"{_CHALLENGE_PREFIX}{challenge_id}", payload, CHALLENGE_TTL)

    result: Dict[str, Any] = {
        "challenge_id": challenge_id,
        "server_nonce": server_nonce,
        "scheme": scheme,
        "instance_binding": get_instance_binding_hex(),
        "transport_iterations": _iterations(),
        "expires_in": CHALLENGE_TTL,
    }
    if not legacy:
        result["salt"] = salt_b64
        result["iterations"] = iterations
    return result


def pop_login_challenge(challenge_id: str) -> Optional[Dict[str, Any]]:
    """Load and consume a one-time login challenge."""
    if not challenge_id:
        return None
    key = f"{_CHALLENGE_PREFIX}{challenge_id}"
    payload = cache.get(key)
    if payload is None:
        return None
    cache.delete(key)
    return payload


