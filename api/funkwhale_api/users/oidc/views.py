"""Public OIDC SSO endpoints for Tayra first-party login."""

from __future__ import annotations

import logging
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

from django.contrib.auth import get_user_model
from django.http import HttpResponse, HttpResponseRedirect
from django.utils.html import escape
from drf_spectacular.utils import extend_schema
from rest_framework.decorators import api_view, authentication_classes, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from funkwhale_api.common import throttling
from funkwhale_api.users import first_party

from . import client as oidc_client
from . import config as oidc_config
from . import redirects as oidc_redirects
from . import session as oidc_session
from . import users as oidc_users

logger = logging.getLogger(__name__)

OOB_REDIRECTS = oidc_redirects.OOB_REDIRECTS


def _is_allowed_client_redirect(value: str) -> bool:
    return oidc_redirects.is_allowed_client_redirect(value)


def _append_query(url: str, params: dict) -> str:
    parts = urlsplit(url)
    query = dict(parse_qsl(parts.query, keep_blank_values=True))
    for key, value in params.items():
        if value is None:
            continue
        query[key] = value
    return urlunsplit(
        (parts.scheme, parts.netloc, parts.path, urlencode(query), parts.fragment)
    )


def _error_redirect(client_redirect: str, error: str, client_state: str = ""):
    if client_redirect in OOB_REDIRECTS:
        return _oob_error_response(error)
    params = {"error": error}
    if client_state:
        params["state"] = client_state
    return HttpResponseRedirect(_append_query(client_redirect, params))


def _success_redirect(client_redirect: str, code: str, client_state: str = ""):
    if client_redirect in OOB_REDIRECTS:
        return _oob_code_response(code)
    params = {"code": code}
    if client_state:
        params["state"] = client_state
    return HttpResponseRedirect(_append_query(client_redirect, params))


def _oob_code_response(code: str) -> HttpResponse:
    safe = escape(code)
    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>SSO login code — Tayra</title>
  <style>
    body {{ font-family: system-ui, sans-serif; background: #000; color: #eee;
           max-width: 32rem; margin: 3rem auto; padding: 0 1rem; }}
    code {{ display: block; word-break: break-all; background: #111;
            border: 1px solid #333; padding: 1rem; border-radius: 8px;
            color: #0af; font-size: 0.95rem; }}
    p {{ line-height: 1.5; color: #bbb; }}
  </style>
</head>
<body>
  <h1>Sign-in code</h1>
  <p>Copy this code into Tayra to finish signing in. It expires in a few minutes.</p>
  <code id="code">{safe}</code>
</body>
</html>
"""
    return HttpResponse(html, content_type="text/html; charset=utf-8")


def _oob_error_response(error: str) -> HttpResponse:
    safe = escape(error)
    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>SSO error — Tayra</title>
  <style>
    body {{ font-family: system-ui, sans-serif; background: #000; color: #eee;
           max-width: 32rem; margin: 3rem auto; padding: 0 1rem; }}
    .err {{ color: #f66; }}
  </style>
</head>
<body>
  <h1>Sign-in failed</h1>
  <p class="err">{safe}</p>
  <p>Return to Tayra and try again, or sign in with username and password.</p>
</body>
</html>
"""
    return HttpResponse(html, content_type="text/html; charset=utf-8")


def _set_tx_cookie(response, tx_binding: str):
    """Bind the SSO transaction to this browser (HttpOnly cookie on API host)."""
    if not tx_binding:
        return
    # Secure when the pod is HTTPS; SameSite=Lax so top-level redirects keep it
    # and the SPA same-site POST to /oidc/token/ includes it.
    from django.conf import settings

    fw = (getattr(settings, "FUNKWHALE_URL", "") or "").lower()
    secure = fw.startswith("https://")
    response.set_cookie(
        oidc_session.TX_COOKIE_NAME,
        tx_binding,
        max_age=oidc_session.TX_COOKIE_MAX_AGE,
        httponly=True,
        samesite="Lax",
        secure=secure,
        path="/",
    )


def _clear_tx_cookie(response):
    response.delete_cookie(oidc_session.TX_COOKIE_NAME, path="/")


def _tx_from_request(request) -> str:
    """SSO transaction binding from cookie or JSON body (native OOB clients)."""
    cookie_val = (request.COOKIES.get(oidc_session.TX_COOKIE_NAME) or "").strip()
    if cookie_val:
        return cookie_val
    data = getattr(request, "data", None) or {}
    if isinstance(data, dict):
        body_val = str(data.get("tx") or data.get("tx_binding") or "").strip()
        if body_val:
            return body_val
    return ""


@extend_schema(
    operation_id="auth_methods",
    description="Public discovery of available authentication methods for clients.",
)
@api_view(["GET"])
@permission_classes([AllowAny])
@authentication_classes([])
def auth_methods(request):
    return Response(
        {
            "password": True,
            "oidc": oidc_config.oidc_public_status(),
        }
    )


@extend_schema(operation_id="oidc_login")
@api_view(["GET"])
@permission_classes([AllowAny])
@authentication_classes([])
def oidc_login(request):
    throttling.check_request(request, "login")
    cfg = oidc_config.get_oidc_config()
    if not cfg["ready"]:
        return Response(
            {
                "error": "oidc_disabled",
                "detail": "OIDC SSO is not enabled or not fully configured.",
            },
            status=404,
        )

    client_redirect = (request.GET.get("client_redirect") or "").strip()
    client_state = (request.GET.get("state") or "").strip()
    if not _is_allowed_client_redirect(client_redirect):
        return Response(
            {
                "error": "invalid_redirect",
                "detail": (
                    "Missing or disallowed client_redirect parameter. "
                    "Use the pod origin, an OOB URN, or a configured allowlist entry."
                ),
            },
            status=400,
        )

    # Optional client-supplied binding for native OOB (app keeps this and
    # posts it with the exchange code). Browser flows use the cookie instead.
    client_tx = (request.GET.get("tx") or "").strip()
    tx_binding = client_tx if client_tx and len(client_tx) >= 16 else oidc_session.new_tx_binding()

    try:
        discovery = oidc_client.fetch_discovery(cfg["discovery_url"])
        code_verifier, code_challenge = oidc_client.generate_pkce_pair()
        nonce = oidc_session.new_token(24)
        state = oidc_session.store_login_state(
            client_redirect=client_redirect,
            client_state=client_state,
            nonce=nonce,
            code_verifier=code_verifier,
            tx_binding=tx_binding,
        )
        auth_url = oidc_client.build_authorization_url(
            discovery=discovery,
            client_id=cfg["client_id"],
            redirect_uri=cfg["callback_uri"],
            scope=cfg["scopes"],
            state=state,
            nonce=nonce,
            code_challenge=code_challenge,
        )
    except oidc_client.OidcError as exc:
        logger.warning("OIDC login start failed: %s", exc.detail)
        return Response(
            {"error": exc.code, "detail": exc.detail},
            status=502,
        )

    response = HttpResponseRedirect(auth_url)
    # Always set cookie so browser-based SPA exchange is bound even when the
    # client also passed tx= for native.
    _set_tx_cookie(response, tx_binding)
    return response


@extend_schema(operation_id="oidc_callback")
@api_view(["GET"])
@permission_classes([AllowAny])
@authentication_classes([])
def oidc_callback(request):
    cfg = oidc_config.get_oidc_config()
    if not cfg["ready"]:
        return Response(
            {"error": "oidc_disabled", "detail": "OIDC SSO is not enabled."},
            status=404,
        )

    error = (request.GET.get("error") or "").strip()
    state = (request.GET.get("state") or "").strip()
    code = (request.GET.get("code") or "").strip()

    pending = oidc_session.pop_login_state(state)
    if pending is None:
        return Response(
            {
                "error": "invalid_state",
                "detail": "Unknown or expired OIDC state.",
            },
            status=400,
        )

    client_redirect = pending.get("client_redirect") or ""
    client_state = pending.get("client_state") or ""
    tx_binding = pending.get("tx_binding") or ""

    # Re-validate redirect at callback time (state may be old / prefs changed).
    if not _is_allowed_client_redirect(client_redirect):
        logger.warning("OIDC callback rejected stored client_redirect")
        return Response(
            {
                "error": "invalid_redirect",
                "detail": "Stored client_redirect is no longer allowed.",
            },
            status=400,
        )

    if error:
        logger.info("OIDC IdP returned error=%s", error)
        response = _error_redirect(
            client_redirect, error or "access_denied", client_state
        )
        _set_tx_cookie(response, tx_binding)
        return response

    if not code:
        response = _error_redirect(client_redirect, "missing_code", client_state)
        _set_tx_cookie(response, tx_binding)
        return response

    try:
        discovery = oidc_client.fetch_discovery(cfg["discovery_url"])
        token_payload = oidc_client.exchange_code(
            discovery=discovery,
            client_id=cfg["client_id"],
            client_secret=cfg["client_secret"],
            code=code,
            redirect_uri=cfg["callback_uri"],
            code_verifier=pending.get("code_verifier") or "",
        )
        claims = oidc_client.validate_id_token(
            id_token=token_payload["id_token"],
            discovery=discovery,
            client_id=cfg["client_id"],
            nonce=pending.get("nonce") or "",
        )
        # Never let UserInfo overwrite the verified id_token subject pair.
        id_iss = claims.get("iss")
        id_sub = claims.get("sub")
        username = oidc_client.extract_username(claims, cfg["username_claim"])
        if not username and token_payload.get("access_token"):
            userinfo = oidc_client.fetch_userinfo(
                discovery=discovery,
                access_token=token_payload["access_token"],
            )
            if userinfo:
                claims = {**claims, **userinfo}
                claims["iss"] = id_iss
                claims["sub"] = id_sub
                username = oidc_client.extract_username(
                    claims, cfg["username_claim"]
                )
        user, _created = oidc_users.resolve_user(
            username=username,
            claims=claims,
            auto_create=cfg["auto_create"],
        )
    except oidc_client.OidcError as exc:
        logger.warning("OIDC callback protocol error: %s", exc.detail)
        response = _error_redirect(client_redirect, exc.code, client_state)
        _set_tx_cookie(response, tx_binding)
        return response
    except oidc_users.OidcUserError as exc:
        logger.info("OIDC user resolution failed: %s", exc.detail)
        response = _error_redirect(client_redirect, exc.code, client_state)
        _set_tx_cookie(response, tx_binding)
        return response
    except Exception:
        logger.exception("OIDC callback unexpected error")
        response = _error_redirect(client_redirect, "server_error", client_state)
        _set_tx_cookie(response, tx_binding)
        return response

    exchange = oidc_session.store_exchange_code(user.pk, tx_binding=tx_binding)
    response = _success_redirect(client_redirect, exchange, client_state)
    # Keep / refresh binding cookie so SPA can redeem without reading the code
    # in a third-party context; OOB clients use the tx they started with.
    _set_tx_cookie(response, tx_binding)
    return response


@extend_schema(
    operation_id="oidc_token",
    description=(
        "Exchange a one-time OIDC login code for first-party OAuth tokens "
        "(same response shape as POST /api/v1/users/token/). Requires the "
        "SSO transaction binding cookie (browser) or ``tx`` body field (native)."
    ),
)
@api_view(["POST"])
@permission_classes([AllowAny])
@authentication_classes([])
def oidc_token(request):
    throttling.check_request(request, "login")
    # Accept any still-valid one-time code even if OIDC was just disabled.

    code = ""
    data = getattr(request, "data", None) or {}
    if isinstance(data, dict):
        code = str(data.get("code") or "").strip()
    if not code:
        # raw body fallback
        try:
            import json

            body = request.body or b""
            if body:
                parsed = json.loads(body.decode("utf-8"))
                if isinstance(parsed, dict):
                    code = str(parsed.get("code") or "").strip()
                    if not data:
                        data = parsed
        except Exception:
            pass

    if not code:
        return Response(
            {
                "error": "missing_code",
                "detail": "One-time code is required.",
            },
            status=400,
        )

    tx_binding = _tx_from_request(request)
    if not tx_binding and isinstance(data, dict):
        tx_binding = str(data.get("tx") or data.get("tx_binding") or "").strip()

    user_id = oidc_session.pop_exchange_code(code, tx_binding=tx_binding)
    if user_id is None:
        return Response(
            {
                "error": "invalid_code",
                "detail": (
                    "Invalid or expired login code, or SSO session binding mismatch."
                ),
            },
            status=400,
        )

    User = get_user_model()
    user = User.objects.all().for_auth().filter(pk=user_id).first()
    if user is None or not user.is_active:
        return Response(
            {
                "error": "inactive",
                "detail": "User account is disabled or missing.",
            },
            status=400,
        )

    # Match password login: confirmed TOTP must be completed before tokens.
    # IdP auth alone must not bypass local 2FA once the user enabled it.
    from funkwhale_api.users import totp as totp_mod

    if totp_mod.is_totp_enabled(user):
        mfa_token = totp_mod.create_mfa_token(user.pk)
        response = Response(
            {
                "error": "totp_required",
                "code": "totp_required",
                "detail": "Two-factor authentication code required.",
                "mfa_token": mfa_token,
            },
            status=401,
        )
        _clear_tx_cookie(response)
        return response

    tokens = first_party.issue_user_tokens(user)
    # Surface force-2FA for password users even when they signed in via SSO.
    tokens["totp_enabled"] = False
    tokens["totp_setup_required"] = totp_mod.needs_totp_setup(user)

    response = Response(tokens)
    _clear_tx_cookie(response)
    return response
