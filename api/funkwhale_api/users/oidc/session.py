"""OIDC login state and one-time token exchange codes (django cache)."""

from __future__ import annotations

import secrets
from typing import Any, Dict, Optional

from django.core.cache import cache

STATE_TTL = 60 * 10  # 10 minutes
CODE_TTL = 60 * 2  # 2 minutes
STATE_PREFIX = "oidc:state:"
CODE_PREFIX = "oidc:code:"


def new_token(nbytes: int = 32) -> str:
    return secrets.token_urlsafe(nbytes)


def store_login_state(
    *,
    client_redirect: str,
    client_state: str,
    nonce: str,
    code_verifier: str,
) -> str:
    """Persist pending auth and return the OIDC ``state`` parameter."""
    state = new_token()
    payload = {
        "client_redirect": client_redirect,
        "client_state": client_state or "",
        "nonce": nonce,
        "code_verifier": code_verifier,
    }
    cache.set(f"{STATE_PREFIX}{state}", payload, STATE_TTL)
    return state


def pop_login_state(state: str) -> Optional[Dict[str, Any]]:
    """Load and delete pending auth state (one-time)."""
    if not state:
        return None
    key = f"{STATE_PREFIX}{state}"
    payload = cache.get(key)
    if payload is None:
        return None
    cache.delete(key)
    return payload


def store_exchange_code(user_id: int) -> str:
    """Mint a short-lived one-time code that maps to ``user_id``."""
    code = new_token(48)
    cache.set(f"{CODE_PREFIX}{code}", {"user_id": user_id}, CODE_TTL)
    return code


def pop_exchange_code(code: str) -> Optional[int]:
    """Consume one-time exchange code; return user_id or None."""
    if not code:
        return None
    key = f"{CODE_PREFIX}{code}"
    payload = cache.get(key)
    if not payload:
        return None
    cache.delete(key)
    try:
        return int(payload["user_id"])
    except (KeyError, TypeError, ValueError):
        return None
