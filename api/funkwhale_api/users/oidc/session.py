"""OIDC login state and one-time token exchange codes (django cache).

Exchange codes are bound to a session binding token (H3). The browser that
started SSO receives an ``oidc_tx`` cookie; redeeming the code requires the
same binding (cookie or explicit ``tx`` field) so a stolen code alone is not
enough to obtain tokens.
"""

from __future__ import annotations

import hashlib
import hmac
import secrets
from typing import Any, Dict, Optional

from django.core.cache import cache

STATE_TTL = 60 * 10  # 10 minutes
CODE_TTL = 60 * 2  # 2 minutes
STATE_PREFIX = "oidc:state:"
CODE_PREFIX = "oidc:code:"

# Cookie / body field name for the SSO transaction binding.
TX_COOKIE_NAME = "oidc_tx"
TX_COOKIE_MAX_AGE = STATE_TTL


def new_token(nbytes: int = 32) -> str:
    return secrets.token_urlsafe(nbytes)


def new_tx_binding() -> str:
    """Cryptographically random binding id for one SSO attempt."""
    return secrets.token_urlsafe(32)


def store_login_state(
    *,
    client_redirect: str,
    client_state: str,
    nonce: str,
    code_verifier: str,
    tx_binding: str,
) -> str:
    """Persist pending auth and return the OIDC ``state`` parameter."""
    state = new_token()
    payload = {
        "client_redirect": client_redirect,
        "client_state": client_state or "",
        "nonce": nonce,
        "code_verifier": code_verifier,
        "tx_binding": tx_binding or "",
    }
    cache.set(f"{STATE_PREFIX}{state}", payload, STATE_TTL)
    return state


def pop_login_state(state: str) -> Optional[Dict[str, Any]]:
    """Load and delete pending auth state (one-time under concurrency)."""
    if not state:
        return None
    key = f"{STATE_PREFIX}{state}"
    payload = cache.get(key)
    if payload is None:
        return None
    claim_key = f"{key}:claimed"
    if not cache.add(claim_key, 1, STATE_TTL):
        return None
    cache.delete(key)
    return payload


def store_exchange_code(user_id: int, tx_binding: str) -> str:
    """Mint a short-lived one-time code bound to ``tx_binding``."""
    code = new_token(48)
    cache.set(
        f"{CODE_PREFIX}{code}",
        {
            "user_id": user_id,
            "tx_binding": tx_binding or "",
        },
        CODE_TTL,
    )
    return code


def pop_exchange_code(code: str, tx_binding: str) -> Optional[int]:
    """Consume one-time exchange code when ``tx_binding`` matches; return user_id."""
    if not code:
        return None
    key = f"{CODE_PREFIX}{code}"
    payload = cache.get(key)
    if not payload:
        return None

    expected = (payload.get("tx_binding") or "") if isinstance(payload, dict) else ""
    provided = tx_binding or ""
    # Codes minted with a binding require a matching presenter binding.
    if expected:
        if not provided or not hmac.compare_digest(expected, provided):
            # Do not delete on mismatch — legitimate client may retry with cookie.
            return None
    # Claim after binding check so wrong-tx retries do not burn the code,
    # while concurrent correct presenters still only mint tokens once.
    claim_key = f"{key}:claimed"
    if not cache.add(claim_key, 1, CODE_TTL):
        return None
    cache.delete(key)
    try:
        return int(payload["user_id"])
    except (KeyError, TypeError, ValueError):
        return None


def hash_tx_binding(tx_binding: str) -> str:
    """Opaque fingerprint for logs (never log the raw binding)."""
    if not tx_binding:
        return ""
    return hashlib.sha256(tx_binding.encode("utf-8")).hexdigest()[:12]
