"""TOTP (RFC 6238) two-factor authentication helpers for first-party login.

Non-SSO (password) users can enable an authenticator app. Login then requires a
time-based code after password verification. Instance admins may force all
password users to configure TOTP via ``users__force_2fa``.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import secrets
import struct
import time
from typing import Iterable, List, Optional, Tuple
from urllib.parse import quote

from django.conf import settings
from django.core import signing
from django.core.cache import cache
from django.utils import timezone

from funkwhale_api.common import preferences

# 30-second steps, SHA-1, 6 digits (Google Authenticator defaults).
TOTP_PERIOD = 30
TOTP_DIGITS = 6
TOTP_WINDOW = 1  # accept ±1 step for clock skew
MFA_TOKEN_SALT = "tayra-mfa-challenge"
MFA_TOKEN_MAX_AGE = 5 * 60  # seconds
SETUP_TOKEN_SALT = "tayra-totp-setup"
SETUP_TOKEN_MAX_AGE = 15 * 60
RECOVERY_CODE_COUNT = 8

# Per-account TOTP / recovery-code lockout (M7) — independent of IP throttling.
TOTP_FAIL_LIMIT = 5
TOTP_FAIL_WINDOW = 15 * 60  # seconds
TOTP_LOCKOUT_SECONDS = 15 * 60


def _totp_fail_cache_key(user_id: int) -> str:
    return f"totp:fail:{int(user_id)}"


def _totp_lock_cache_key(user_id: int) -> str:
    return f"totp:lock:{int(user_id)}"


def is_totp_locked(user_id: int) -> bool:
    """True when this account is temporarily locked after failed 2FA attempts."""
    return bool(cache.get(_totp_lock_cache_key(user_id)))


def record_totp_failure(user_id: int) -> bool:
    """
    Record a failed TOTP/recovery attempt for ``user_id``.

    Returns True if the account is now locked (or was already locked).
    """
    uid = int(user_id)
    if is_totp_locked(uid):
        return True
    key = _totp_fail_cache_key(uid)
    try:
        count = cache.incr(key)
    except ValueError:
        cache.set(key, 1, TOTP_FAIL_WINDOW)
        count = 1
    if count >= TOTP_FAIL_LIMIT:
        cache.set(_totp_lock_cache_key(uid), 1, TOTP_LOCKOUT_SECONDS)
        cache.delete(key)
        return True
    return False


def clear_totp_failures(user_id: int) -> None:
    """Clear failure counter and lockout after a successful 2FA verification."""
    uid = int(user_id)
    cache.delete(_totp_fail_cache_key(uid))
    cache.delete(_totp_lock_cache_key(uid))


def generate_base32_secret(num_bytes: int = 20) -> str:
    """Return a base32-encoded shared secret (no padding)."""
    raw = secrets.token_bytes(num_bytes)
    return base64.b32encode(raw).decode("ascii").rstrip("=")


def _normalize_secret(secret: str) -> bytes:
    s = (secret or "").strip().upper().replace(" ", "")
    # Restore padding for base64.b32decode
    pad = (-len(s)) % 8
    if pad:
        s = s + ("=" * pad)
    return base64.b32decode(s, casefold=True)


def totp_at(secret: str, for_time: Optional[float] = None, period: int = TOTP_PERIOD) -> str:
    """Compute the TOTP code for ``secret`` at ``for_time`` (unix seconds)."""
    if for_time is None:
        for_time = time.time()
    counter = int(for_time) // period
    return _hotp(_normalize_secret(secret), counter, digits=TOTP_DIGITS)


def _hotp(key: bytes, counter: int, digits: int = TOTP_DIGITS) -> str:
    msg = struct.pack(">Q", counter)
    digest = hmac.new(key, msg, hashlib.sha1).digest()
    offset = digest[-1] & 0x0F
    code_int = struct.unpack(">I", digest[offset : offset + 4])[0] & 0x7FFFFFFF
    return str(code_int % (10**digits)).zfill(digits)


def verify_totp(
    secret: str,
    code: str,
    *,
    window: int = TOTP_WINDOW,
    period: int = TOTP_PERIOD,
    last_used_step: Optional[int] = None,
    now: Optional[float] = None,
) -> Tuple[bool, Optional[int]]:
    """
    Verify a user-supplied TOTP ``code``.

    Returns ``(ok, used_step)``. When ok, ``used_step`` is the matching time
    step (for replay protection). Rejects codes that match ``last_used_step``.
    """
    if not secret or not code:
        return False, None
    digits = "".join(c for c in str(code) if c.isdigit())
    if len(digits) != TOTP_DIGITS:
        return False, None

    if now is None:
        now = time.time()
    current_step = int(now) // period
    try:
        key = _normalize_secret(secret)
    except Exception:
        return False, None

    for delta in range(-window, window + 1):
        step = current_step + delta
        if last_used_step is not None and step == last_used_step:
            continue
        if _hotp(key, step) == digits:
            return True, step
    return False, None


def provisioning_uri(
    secret: str,
    *,
    account_name: str,
    issuer: Optional[str] = None,
) -> str:
    """Build an ``otpauth://totp/...`` URI for authenticator apps / QR codes."""
    issuer = (issuer or "").strip() or _default_issuer()
    label = f"{issuer}:{account_name}" if issuer else account_name
    params = (
        f"secret={quote(secret, safe='')}"
        f"&issuer={quote(issuer, safe='')}"
        f"&algorithm=SHA1&digits={TOTP_DIGITS}&period={TOTP_PERIOD}"
    )
    return f"otpauth://totp/{quote(label)}?{params}"


def _default_issuer() -> str:
    try:
        name = preferences.get("instance__name")
        if name:
            return str(name)[:64]
    except Exception:
        pass
    hostname = getattr(settings, "FEDERATION_HOSTNAME", None) or "Tayra"
    return str(hostname)[:64]


# At-rest encryption for TotpDevice.secret (Fernet-like via Django signing).
_TOTP_SECRET_SALT = "tayra-totp-device-secret"
_TOTP_SECRET_PREFIX = "enc1:"


def protect_totp_secret(secret: str) -> str:
    """Encrypt a base32 TOTP secret for database storage."""
    if not secret:
        return secret
    if secret.startswith(_TOTP_SECRET_PREFIX):
        return secret
    return _TOTP_SECRET_PREFIX + signing.dumps(
        secret, salt=_TOTP_SECRET_SALT
    )


def reveal_totp_secret(stored: str) -> str:
    """Decrypt a stored TOTP secret; accept legacy plaintext base32 rows."""
    if not stored:
        return ""
    if stored.startswith(_TOTP_SECRET_PREFIX):
        try:
            return signing.loads(
                stored[len(_TOTP_SECRET_PREFIX) :], salt=_TOTP_SECRET_SALT
            )
        except signing.BadSignature:
            return ""
    # Legacy unencrypted base32 secret.
    return stored


def is_totp_enabled(user) -> bool:
    """True when the user has a confirmed TOTP device.

    Always hits the database (not the reverse-descriptor cache) so a
    long-lived ``request.user`` / force_authenticate object cannot report
    a stale pre-setup or pre-confirm state within the same process.
    """
    from funkwhale_api.users import models as users_models

    if user is None or not getattr(user, "pk", None):
        return False
    try:
        device = users_models.TotpDevice.objects.filter(user_id=user.pk).first()
    except Exception:
        return False
    return bool(device and device.confirmed and reveal_totp_secret(device.secret))


def is_password_user(user) -> bool:
    """True when the account can use password login (non-SSO-only)."""
    try:
        return user.has_usable_password()
    except Exception:
        return False


def force_2fa_enabled() -> bool:
    try:
        return bool(preferences.get("users__force_2fa"))
    except Exception:
        return False


def needs_totp_setup(user) -> bool:
    """Instance requires TOTP and this password user has not configured it."""
    if not force_2fa_enabled():
        return False
    if not is_password_user(user):
        return False
    return not is_totp_enabled(user)


def _mfa_jti_cache_key(jti: str) -> str:
    return f"mfa:jti:{jti}"


def create_mfa_token(user_id: int) -> str:
    """Mint a short-lived MFA challenge token with a single-use ``jti``."""
    jti = secrets.token_urlsafe(16)
    cache.set(_mfa_jti_cache_key(jti), int(user_id), MFA_TOKEN_MAX_AGE)
    return signing.dumps(
        {"uid": int(user_id), "t": "totp", "j": jti}, salt=MFA_TOKEN_SALT
    )


def load_mfa_token(token: str) -> Optional[int]:
    """Validate signature/age and that the jti has not been consumed yet.

    Does **not** consume the token (callers may retry wrong TOTP codes).
    """
    try:
        payload = signing.loads(
            token, salt=MFA_TOKEN_SALT, max_age=MFA_TOKEN_MAX_AGE
        )
    except signing.BadSignature:
        return None
    try:
        if payload.get("t") != "totp":
            return None
        uid = int(payload["uid"])
        jti = payload.get("j")
        if not jti:
            # Pre-jti tokens (should not appear after upgrade) — reject.
            return None
        cached = cache.get(_mfa_jti_cache_key(str(jti)))
        if cached is None:
            return None
        if int(cached) != uid:
            return None
        return uid
    except (KeyError, TypeError, ValueError):
        return None


def consume_mfa_token(token: str) -> Optional[int]:
    """Validate and invalidate an MFA token (single successful use)."""
    try:
        payload = signing.loads(
            token, salt=MFA_TOKEN_SALT, max_age=MFA_TOKEN_MAX_AGE
        )
    except signing.BadSignature:
        return None
    try:
        if payload.get("t") != "totp":
            return None
        uid = int(payload["uid"])
        jti = payload.get("j")
        if not jti:
            return None
        key = _mfa_jti_cache_key(str(jti))
        cached = cache.get(key)
        if cached is None or int(cached) != uid:
            return None
        cache.delete(key)
        return uid
    except (KeyError, TypeError, ValueError):
        return None


def hash_recovery_code(code: str) -> str:
    """Hash a recovery code with a domain-separated digest.

    Codes are high-entropy (≥128 bits); SHA-256 with a fixed domain label is
    enough to block naive rainbow tables. Per-row salt would require a schema
    change and is unnecessary at this entropy.
    """
    normalized = normalize_recovery_code(code)
    return hashlib.sha256(
        b"tayra-totp-recovery\0" + normalized.encode("utf-8")
    ).hexdigest()


def _legacy_hash_recovery_code(code: str) -> str:
    """Pre-domain-separation hash (still accepted for existing rows)."""
    normalized = normalize_recovery_code(code)
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def normalize_recovery_code(code: str) -> str:
    return "".join(c for c in (code or "").upper() if c.isalnum())


def generate_recovery_codes(count: int = RECOVERY_CODE_COUNT) -> List[str]:
    """Return human-readable recovery codes (shown once to the user).

    Each code is 128 bits of entropy (32 hex chars), grouped for readability.
    """
    codes = []
    for _ in range(count):
        raw = secrets.token_hex(16).upper()  # 32 hex chars ≈ 128 bits
        parts = [raw[i : i + 4] for i in range(0, 32, 4)]
        codes.append("-".join(parts))
    return codes


def store_recovery_codes(user, plain_codes: Iterable[str]) -> None:
    from funkwhale_api.users.models import TotpRecoveryCode

    TotpRecoveryCode.objects.filter(user=user).delete()
    TotpRecoveryCode.objects.bulk_create(
        [
            TotpRecoveryCode(user=user, code_hash=hash_recovery_code(c))
            for c in plain_codes
        ]
    )


def consume_recovery_code(user, code: str) -> bool:
    from funkwhale_api.users.models import TotpRecoveryCode

    if len(normalize_recovery_code(code)) < 8:
        return False
    digests = {hash_recovery_code(code), _legacy_hash_recovery_code(code)}
    digests.discard("")
    if not digests:
        return False
    row = (
        TotpRecoveryCode.objects.filter(
            user=user, code_hash__in=digests, used_at__isnull=True
        )
        .select_for_update()
        .first()
    )
    if row is None:
        return False
    row.used_at = timezone.now()
    row.save(update_fields=["used_at"])
    return True


def verify_user_totp(user, code: str) -> bool:
    """Verify TOTP or recovery code for a confirmed device; update last step."""
    from django.db import transaction

    from funkwhale_api.users.models import TotpDevice

    with transaction.atomic():
        try:
            device = TotpDevice.objects.select_for_update().get(
                user=user, confirmed=True
            )
        except TotpDevice.DoesNotExist:
            return False

        ok, step = verify_totp(
            reveal_totp_secret(device.secret),
            code,
            last_used_step=device.last_used_step,
        )
        if ok and step is not None:
            device.last_used_step = step
            device.save(update_fields=["last_used_step"])
            return True

        # Recovery codes are longer / dashed — try if TOTP failed.
        return consume_recovery_code(user, code)
