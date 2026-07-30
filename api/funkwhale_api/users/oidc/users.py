"""Match OIDC identity to local User rows (and optional auto-create)."""

from __future__ import annotations

import logging
import re
from typing import Any, Dict, Optional, Tuple

from django.contrib.auth import get_user_model

from funkwhale_api.common import preferences

logger = logging.getLogger(__name__)

# Align with registration: ASCII word chars (AbstractUser validator uses similar).
_USERNAME_RE = re.compile(r"^[\w.@+-]+$", re.UNICODE)


class OidcUserError(Exception):
    def __init__(self, code: str, detail: str = ""):
        self.code = code
        self.detail = detail or code
        super().__init__(self.detail)


def resolve_user(
    *,
    username: str,
    claims: Dict[str, Any],
    auto_create: bool,
) -> Tuple[Any, bool]:
    """
    Return ``(user, created)``.

    Matches ``User.username`` case-insensitively. Does not match by email
    unless the configured claim itself is the username.
    """
    User = get_user_model()
    username = (username or "").strip()
    if not username:
        raise OidcUserError("missing_username", "OIDC username claim is empty")

    user = User.objects.all().for_auth().filter(username__iexact=username).first()
    if user is not None:
        if not user.is_active:
            raise OidcUserError("inactive", "User account is disabled")
        return user, False

    if not auto_create:
        raise OidcUserError(
            "user_not_found",
            "No local account matches this SSO username",
        )

    return _create_user(username=username, claims=claims), True


def _create_user(*, username: str, claims: Dict[str, Any]):
    User = get_user_model()
    # Keep usernames compatible with Funkwhale validators.
    if not _USERNAME_RE.match(username) or len(username) > 150:
        raise OidcUserError(
            "invalid_username",
            "OIDC username is not a valid local username",
        )
    if User.objects.filter(username__iexact=username).exists():
        # Race: another request created it.
        user = User.objects.all().for_auth().filter(username__iexact=username).first()
        if user and user.is_active:
            return user
        raise OidcUserError("user_not_found", "Could not create local account")

    email = ""
    raw_email = claims.get("email")
    if isinstance(raw_email, str):
        email = raw_email.strip()[:254]

    name = ""
    for key in ("name", "given_name"):
        raw = claims.get(key)
        if isinstance(raw, str) and raw.strip():
            name = raw.strip()[:255]
            break

    user = User(username=username, email=email or "", name=name)
    user.set_unusable_password()
    # Apply default permissions like registration path when present.
    try:
        default_perms = preferences.get("users__default_permissions") or []
        for perm in default_perms:
            field = f"permission_{perm}"
            if hasattr(user, field):
                setattr(user, field, True)
    except Exception:
        logger.exception("OIDC auto-create: failed applying default permissions")

    user.save()
    if not user.actor_id:
        try:
            user.create_actor()
        except Exception:
            logger.exception("OIDC auto-create: failed creating actor for %s", username)
    logger.info("OIDC auto-created user username=%s", username)
    return user
