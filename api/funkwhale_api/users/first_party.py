"""First-party (Tayra) OAuth application helpers and token issuance.

The Vue SPA is gone; Tayra is the primary client. Same-origin web and native
clients can exchange username/password for OAuth access + refresh tokens in one
API call instead of the OOB authorization-code dance.
"""

from __future__ import annotations

import datetime
import secrets

from django.conf import settings
from django.db import transaction
from django.utils import timezone
from oauth2_provider.settings import oauth2_settings

from funkwhale_api.users import authentication as users_authentication
from funkwhale_api.users import models

# Stable name so we reuse a single Application row across logins.
FIRST_PARTY_APP_NAME = "Tayra"

# Scopes used by the first-party client (matches historical web client).
FIRST_PARTY_SCOPES = "read write"


def _generate_token() -> str:
    return secrets.token_urlsafe(48)


@transaction.atomic
def get_or_create_first_party_application() -> tuple[models.Application, str]:
    """
    Return ``(application, plain_client_secret)``.

    On first creation the plain secret is the value we set; on reuse we return
    the stored secret (Funkwhale 1.4 DOT does not hash client secrets).
    """
    from oauth2_provider.generators import generate_client_id, generate_client_secret

    app = (
        models.Application.objects.select_for_update()
        .filter(name=FIRST_PARTY_APP_NAME, user__isnull=True)
        .first()
    )
    if app:
        return app, app.client_secret

    plain_secret = generate_client_secret()
    app = models.Application(
        name=FIRST_PARTY_APP_NAME,
        client_id=generate_client_id(),
        client_secret=plain_secret,
        client_type=models.Application.CLIENT_CONFIDENTIAL,
        authorization_grant_type=models.Application.GRANT_PASSWORD,
        redirect_uris="\n".join(
            [
                "urn:ietf:wg:oauth:2.0:oob",
                "urn:ietf:wg:oauth:2.0:oob:auto",
            ]
        ),
        scope=FIRST_PARTY_SCOPES,
        skip_authorization=True,
        user=None,
    )
    app.save()
    return app, plain_secret


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
