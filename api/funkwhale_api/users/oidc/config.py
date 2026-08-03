"""Resolve effective OIDC configuration from environment variables only."""

from __future__ import annotations

import logging
from typing import Any, Dict

from django.conf import settings

logger = logging.getLogger(__name__)

DEFAULT_SCOPES = "openid profile email"
DEFAULT_USERNAME_CLAIM = "preferred_username"
DEFAULT_DISPLAY_NAME = "SSO"

LOGIN_PATH = "/api/v1/users/oidc/login/"
CALLBACK_PATH = "/api/v1/users/oidc/callback/"


def _env_str(name: str, default: str = "") -> str:
    return str(getattr(settings, name, default) or default).strip()


def _env_bool(name: str, default: bool = False) -> bool:
    return bool(getattr(settings, name, default))


def get_oidc_config() -> Dict[str, Any]:
    """
    Read OIDC settings from environment / Django settings only.

    Instance preferences (``users__oidc_*``) are intentionally ignored so
    configuration is sole-sourced from the ``.env`` file. Any values previously
    stored via the instance settings UI have no effect.
    """
    discovery = _env_str("OIDC_DISCOVERY_URL")
    client_id = _env_str("OIDC_CLIENT_ID")
    client_secret = _env_str("OIDC_CLIENT_SECRET")
    scopes = _env_str("OIDC_SCOPES", DEFAULT_SCOPES) or DEFAULT_SCOPES
    username_claim = (
        _env_str("OIDC_USERNAME_CLAIM", DEFAULT_USERNAME_CLAIM)
        or DEFAULT_USERNAME_CLAIM
    )
    display_name = (
        _env_str("OIDC_DISPLAY_NAME", DEFAULT_DISPLAY_NAME) or DEFAULT_DISPLAY_NAME
    )
    enabled = _env_bool("OIDC_ENABLED")
    auto_create = _env_bool("OIDC_AUTO_CREATE")

    # Client secret is optional for public clients that rely on PKCE only.
    ready = bool(enabled and discovery and client_id)

    return {
        "enabled": enabled,
        "ready": ready,
        "discovery_url": discovery,
        "client_id": client_id,
        "client_secret": client_secret,
        "scopes": scopes,
        "username_claim": username_claim,
        "display_name": display_name,
        "auto_create": auto_create,
        "login_path": LOGIN_PATH,
        "callback_path": CALLBACK_PATH,
        "callback_uri": f"{settings.FUNKWHALE_URL.rstrip('/')}{CALLBACK_PATH}",
    }


def oidc_public_status() -> Dict[str, Any]:
    """Safe public subset for auth-methods discovery (no secrets)."""
    cfg = get_oidc_config()
    if cfg["enabled"] and not cfg["ready"]:
        logger.warning(
            "OIDC is enabled but incomplete (missing discovery URL or client id)"
        )
    return {
        "enabled": bool(cfg["ready"]),
        "display_name": cfg["display_name"],
        "login_path": cfg["login_path"],
    }
