"""Match OIDC identity to local User rows (and optional auto-create).

Primary key is the IdP subject pair ``(iss, sub)`` stored in
:class:`~funkwhale_api.users.models.OidcIdentity`. Username claims are only
used for first-time link / auto-create, never as the sole long-term identity.
"""

from __future__ import annotations

import logging
import re
from typing import Any, Dict, Tuple

from django.contrib.auth import get_user_model
from django.db import IntegrityError, transaction
from django.utils import timezone

from funkwhale_api.common import preferences
from funkwhale_api.users import models as users_models

logger = logging.getLogger(__name__)

# Align with registration: ASCII word chars (AbstractUser validator uses similar).
_USERNAME_RE = re.compile(r"^[\w.@+-]+$", re.UNICODE)

# Reasonable bounds for iss / sub storage.
_MAX_ISSUER_LEN = 512
_MAX_SUBJECT_LEN = 255


class OidcUserError(Exception):
    def __init__(self, code: str, detail: str = ""):
        self.code = code
        self.detail = detail or code
        super().__init__(self.detail)


def extract_subject_binding(claims: Dict[str, Any]) -> Tuple[str, str]:
    """Return ``(issuer, subject)`` from validated ID-token claims.

    Both are required. Callers must pass claims from a verified id_token
    (``iss`` and ``sub`` already checked by the JWT library).
    """
    if not isinstance(claims, dict):
        raise OidcUserError("missing_subject", "OIDC claims are missing")

    issuer = claims.get("iss")
    subject = claims.get("sub")
    if not isinstance(issuer, str) or not issuer.strip():
        raise OidcUserError("missing_issuer", "OIDC issuer (iss) claim is empty")
    if subject is None or (isinstance(subject, str) and not subject.strip()):
        raise OidcUserError("missing_subject", "OIDC subject (sub) claim is empty")

    issuer = str(issuer).strip()
    subject = str(subject).strip()
    if len(issuer) > _MAX_ISSUER_LEN or len(subject) > _MAX_SUBJECT_LEN:
        raise OidcUserError(
            "invalid_subject",
            "OIDC issuer or subject exceeds allowed length",
        )
    return issuer, subject


def resolve_user(
    *,
    username: str,
    claims: Dict[str, Any],
    auto_create: bool,
) -> Tuple[Any, bool]:
    """
    Return ``(user, created)``.

    Resolution order:

    1. **Stable subject binding** — ``OidcIdentity(issuer, subject)``.
    2. **First-time username link** — if no binding exists for this ``sub``,
       match ``User.username`` (case-insensitive) and create the binding.
       Refused when that local user is already bound to a *different* ``sub``
       for the same issuer (prevents claim hijack after the real owner linked).
    3. **Auto-create** (when enabled) — create user + binding.
    """
    issuer, subject = extract_subject_binding(claims)

    # ── 1. Primary: issuer + sub ──────────────────────────────────────────
    identity = (
        users_models.OidcIdentity.objects.select_related("user")
        .filter(issuer=issuer, subject=subject)
        .first()
    )
    if identity is not None:
        user = identity.user
        if not user.is_active:
            raise OidcUserError("inactive", "User account is disabled")
        _touch_identity(identity)
        return user, False

    # ── 2 / 3. First-time link or create (needs a username claim) ────────
    username = (username or "").strip()
    if not username:
        raise OidcUserError(
            "missing_username",
            "OIDC username claim is empty (required for first-time SSO link)",
        )

    User = get_user_model()
    user = User.objects.all().for_auth().filter(username__iexact=username).first()
    if user is not None:
        if not user.is_active:
            raise OidcUserError("inactive", "User account is disabled")
        _first_time_link(user=user, issuer=issuer, subject=subject)
        return user, False

    if not auto_create:
        raise OidcUserError(
            "user_not_found",
            "No local account matches this SSO identity",
        )

    user = _create_user(username=username, claims=claims)
    _first_time_link(user=user, issuer=issuer, subject=subject)
    return user, True


def _touch_identity(identity: users_models.OidcIdentity) -> None:
    try:
        users_models.OidcIdentity.objects.filter(pk=identity.pk).update(
            last_login_at=timezone.now()
        )
    except Exception:
        logger.exception("OIDC: failed updating last_login_at for identity %s", identity.pk)


@transaction.atomic
def _first_time_link(*, user, issuer: str, subject: str) -> users_models.OidcIdentity:
    """Bind ``(issuer, subject)`` to ``user`` on first SSO for this subject.

    Refuses if ``user`` already has a different subject under the same issuer.
    Concurrent first logins for the same subject are handled via unique constraint.
    """
    # Another concurrent request may have just created the binding.
    existing_sub = (
        users_models.OidcIdentity.objects.select_for_update()
        .filter(issuer=issuer, subject=subject)
        .first()
    )
    if existing_sub is not None:
        if existing_sub.user_id != user.pk:
            raise OidcUserError(
                "subject_conflict",
                "This SSO identity is already linked to another account",
            )
        _touch_identity(existing_sub)
        return existing_sub

    # User already linked to a different subject at this IdP → do not steal.
    other = (
        users_models.OidcIdentity.objects.select_for_update()
        .filter(user=user, issuer=issuer)
        .exclude(subject=subject)
        .first()
    )
    if other is not None:
        raise OidcUserError(
            "username_conflict",
            "This local username is already linked to a different SSO identity",
        )

    try:
        identity = users_models.OidcIdentity.objects.create(
            user=user,
            issuer=issuer,
            subject=subject,
            last_login_at=timezone.now(),
        )
    except IntegrityError:
        # Lost race on unique (issuer, subject).
        identity = users_models.OidcIdentity.objects.get(
            issuer=issuer, subject=subject
        )
        if identity.user_id != user.pk:
            raise OidcUserError(
                "subject_conflict",
                "This SSO identity is already linked to another account",
            )
        _touch_identity(identity)
        return identity

    logger.info(
        "OIDC first-time link user_id=%s issuer=%s subject=%s",
        user.pk,
        issuer[:64],
        subject[:32],
    )
    return identity


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
