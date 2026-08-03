"""First-party (Tayra) OAuth application helpers and token issuance.

The Vue SPA is gone; Tayra is the primary client. Same-origin web and native
clients can exchange username + transport-hashed password for OAuth access +
refresh tokens in one API call instead of the OOB authorization-code dance.
"""

from __future__ import annotations

import datetime
import secrets

from django.db import transaction
from django.utils import timezone
from oauth2_provider.settings import oauth2_settings

from funkwhale_api.users import authentication as users_authentication
from funkwhale_api.users import models

# Stable name so we reuse a single Application row across logins.
FIRST_PARTY_APP_NAME = "Tayra"

# Scopes used by the first-party client (matches historical web client).
FIRST_PARTY_SCOPES = "read write"

# Preferred native deep-link callbacks (M2); OOB kept for paste-code flows.
FIRST_PARTY_REDIRECT_URIS = "\n".join(
    [
        "tayra://oauth/callback",
        "tayra://sso/callback",
        "urn:ietf:wg:oauth:2.0:oob",
        "urn:ietf:wg:oauth:2.0:oob:auto",
    ]
)


def _generate_token() -> str:
    return secrets.token_urlsafe(48)


@transaction.atomic
def get_or_create_first_party_application() -> tuple[models.Application, str]:
    """
    Return ``(application, plain_client_secret)``.

    The first-party SPA is a **public** OAuth client: django-oauth-toolkit 2.x
    hashes ``client_secret`` on save, and this Application is shared by every
    Tayra login. Returning a hashed secret (or rotating a confidential secret
    on each login) breaks refresh for other sessions. Public clients do not
    need a secret for token refresh.
    """
    from oauth2_provider.generators import generate_client_id

    app = (
        models.Application.objects.select_for_update()
        .filter(name=FIRST_PARTY_APP_NAME, user__isnull=True)
        .first()
    )
    if app:
        dirty = False
        # Migrate any confidential Tayra app created by older builds.
        if app.client_type != models.Application.CLIENT_PUBLIC:
            app.client_type = models.Application.CLIENT_PUBLIC
            dirty = True
        if app.authorization_grant_type != models.Application.GRANT_AUTHORIZATION_CODE:
            # Tokens are issued out-of-band; grant type only documents the app.
            app.authorization_grant_type = models.Application.GRANT_AUTHORIZATION_CODE
            dirty = True
        # Ensure preferred redirect URIs are present (additive).
        existing = set((app.redirect_uris or "").split())
        desired = set(FIRST_PARTY_REDIRECT_URIS.split())
        if not desired.issubset(existing):
            app.redirect_uris = "\n".join(sorted(existing | desired))
            dirty = True
        if dirty:
            app.save()
        return app, ""

    app = models.Application(
        name=FIRST_PARTY_APP_NAME,
        client_id=generate_client_id(),
        # Blank secret is fine for public clients; DOT may still hash it.
        client_secret="",
        client_type=models.Application.CLIENT_PUBLIC,
        authorization_grant_type=models.Application.GRANT_AUTHORIZATION_CODE,
        redirect_uris=FIRST_PARTY_REDIRECT_URIS,
        scope=FIRST_PARTY_SCOPES,
        skip_authorization=True,
        user=None,
    )
    app.save()
    return app, ""


@transaction.atomic
def issue_user_tokens(user: models.User) -> dict:
    """
    Issue access + refresh tokens and a scoped listen token for ``user``.

    Returns a dict suitable for a JSON API response (OAuth-shaped fields).
    """
    application, client_secret = get_or_create_first_party_application()

    access_expires = timezone.now() + datetime.timedelta(
        seconds=oauth2_settings.ACCESS_TOKEN_EXPIRE_SECONDS
    )
    access = models.AccessToken.objects.create(
        user=user,
        application=application,
        token=_generate_token(),
        expires=access_expires,
        scope=FIRST_PARTY_SCOPES,
    )
    refresh = models.RefreshToken.objects.create(
        user=user,
        application=application,
        token=_generate_token(),
        access_token=access,
    )
    listen = users_authentication.generate_scoped_token(
        user_id=user.pk,
        user_secret=str(user.secret_key),
        scopes=["read:libraries"],
    )

    return {
        "access_token": access.token,
        "refresh_token": refresh.token,
        "token_type": "Bearer",
        "scope": FIRST_PARTY_SCOPES,
        "expires_in": oauth2_settings.ACCESS_TOKEN_EXPIRE_SECONDS,
        "client_id": application.client_id,
        "client_secret": client_secret,
        "listen_token": listen,
    }
