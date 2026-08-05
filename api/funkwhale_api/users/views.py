import json
import logging

from allauth.account.adapter import get_adapter
from dj_rest_auth import views as rest_auth_views
from dj_rest_auth.registration import views as registration_views
from django import http
from django.contrib import auth
from django.contrib.auth import get_user_model
from django.middleware import csrf
from drf_spectacular.utils import extend_schema, extend_schema_view
from rest_framework import mixins, viewsets
from rest_framework.decorators import action, api_view, authentication_classes, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from funkwhale_api.common import authentication, preferences, throttling

from . import models, serializers, tasks

logger = logging.getLogger(__name__)


@extend_schema_view(post=extend_schema(operation_id="register", methods=["post"]))
class RegisterView(registration_views.RegisterView):
    serializer_class = serializers.RegisterSerializer
    permission_classes = []
    action = "signup"
    throttling_scopes = {"signup": {"authenticated": "signup", "anonymous": "signup"}}

    def create(self, request, *args, **kwargs):
        invitation_code = request.data.get("invitation")
        if not invitation_code and not self.is_open_for_signup(request):
            r = {"detail": "Registration has been disabled"}
            return Response(r, status=403)
        return super().create(request, *args, **kwargs)

    def is_open_for_signup(self, request):
        return get_adapter().is_open_for_signup(request)

    def perform_create(self, serializer):
        user = super().perform_create(serializer)
        if not user.is_active:
            # manual approval, we need to send the confirmation e-mail by hand
            authentication.send_email_confirmation(self.request, user)
        if user.invitation:
            user.invitation.set_invited_user(user)

        return user


@extend_schema_view(post=extend_schema(operation_id="verify_email"))
class VerifyEmailView(registration_views.VerifyEmailView):
    action = "verify-email"


@extend_schema_view(post=extend_schema(operation_id="change_password"))
class PasswordChangeView(rest_auth_views.PasswordChangeView):
    """Change password; requires SCRAM step-up proof instead of old_password (H2)."""

    action = "password-change"
    serializer_class = serializers.PasswordChangeSerializer

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response({"detail": "New password has been saved."})


@extend_schema_view(post=extend_schema(operation_id="reset_password"))
class PasswordResetView(rest_auth_views.PasswordResetView):
    action = "password-reset"


@extend_schema_view(post=extend_schema(operation_id="confirm_password_reset"))
class PasswordResetConfirmView(rest_auth_views.PasswordResetConfirmView):
    action = "password-reset-confirm"


class UserViewSet(mixins.UpdateModelMixin, viewsets.GenericViewSet):
    queryset = models.User.objects.all().select_related("actor__attachment_icon")
    serializer_class = serializers.UserWriteSerializer
    lookup_field = "username"
    lookup_value_regex = r"[a-zA-Z0-9-_.]+"
    required_scope = "profile"

    @extend_schema(operation_id="get_authenticated_user", methods=["get"])
    @extend_schema(operation_id="delete_authenticated_user", methods=["delete"])
    @action(methods=["get", "delete"], detail=False)
    def me(self, request, *args, **kwargs):
        """Return information about the current user or delete it"""
        if request.method.lower() == "delete":
            serializer = serializers.UserDeleteSerializer(
                request.user, data=request.data
            )
            serializer.is_valid(raise_exception=True)
            tasks.delete_account.delay(user_id=request.user.pk)
            # at this point, password is valid, we launch deletion
            return Response(status=204)
        serializer = serializers.MeSerializer(request.user)
        return Response(serializer.data)

    @extend_schema(operation_id="deactivate_authenticated_user")
    @action(
        methods=["post"],
        detail=False,
        url_path="me/deactivate",
        url_name="me-deactivate",
        required_scope="security",
    )
    def deactivate_me(self, request, *args, **kwargs):
        """Soft-disable the current account (reversible by an admin).

        Requires password confirmation when the account has a usable password.
        Immediately logs the user out by revoking OAuth tokens.
        """
        if not request.user.is_authenticated:
            return Response(status=403)
        serializer = serializers.UserDeactivateSerializer(
            request.user, data=request.data
        )
        serializer.is_valid(raise_exception=True)
        request.user.deactivate()
        return Response(status=204)

    @extend_schema(operation_id="update_settings")
    @action(methods=["post"], detail=False, url_name="settings", url_path="settings")
    def set_settings(self, request, *args, **kwargs):
        """Return information about the current user or delete it"""
        new_settings = request.data
        request.user.set_settings(**new_settings)
        return Response(request.user.settings)

    @action(
        methods=["get", "post", "delete"],
        required_scope="security",
        url_path="subsonic-token",
        detail=True,
    )
    def subsonic_token(self, request, *args, **kwargs):
        if not self.request.user.username == kwargs.get("username"):
            return Response(status=403)
        if not preferences.get("subsonic__enabled"):
            return Response(status=405)
        if request.method.lower() == "get":
            return Response(
                {"subsonic_api_token": self.request.user.subsonic_api_token}
            )
        if request.method.lower() == "delete":
            self.request.user.subsonic_api_token = None
            self.request.user.save(update_fields=["subsonic_api_token"])
            return Response(status=204)
        self.request.user.update_subsonic_api_token()
        self.request.user.save(update_fields=["subsonic_api_token"])
        data = {"subsonic_api_token": self.request.user.subsonic_api_token}
        return Response(data)

    @extend_schema(operation_id="change_email", responses={200: None, 403: None})
    @action(
        methods=["post"],
        required_scope="security",
        url_path="change-email",
        detail=False,
    )
    def change_email(self, request, *args, **kwargs):
        if not self.request.user.is_authenticated:
            return Response(status=403)
        serializer = serializers.UserChangeEmailSerializer(
            request.user, data=request.data, context={"user": request.user}
        )
        serializer.is_valid(raise_exception=True)
        serializer.save(request)
        return Response(status=204)

    # ── TOTP 2FA ─────────────────────────────────────────────────────────

    @extend_schema(operation_id="totp_status")
    @action(
        methods=["get"],
        detail=False,
        url_path="me/2fa",
        url_name="me-2fa",
        required_scope="security",
    )
    def totp_status(self, request, *args, **kwargs):
        """Return whether TOTP is enabled and whether the instance requires it."""
        from funkwhale_api.users import totp as totp_mod

        user = request.user
        if not user.is_authenticated:
            return Response(status=403)
        remaining = models.TotpRecoveryCode.objects.filter(
            user=user, used_at__isnull=True
        ).count()
        return Response(
            {
                "enabled": totp_mod.is_totp_enabled(user),
                "required": totp_mod.needs_totp_setup(user),
                "force_2fa": totp_mod.force_2fa_enabled(),
                "is_password_user": totp_mod.is_password_user(user),
                "recovery_codes_remaining": remaining
                if totp_mod.is_totp_enabled(user)
                else 0,
            }
        )

    @extend_schema(operation_id="totp_setup")
    @action(
        methods=["post"],
        detail=False,
        url_path="me/2fa/setup",
        url_name="me-2fa-setup",
        required_scope="security",
    )
    def totp_setup(self, request, *args, **kwargs):
        """Start or restart TOTP enrollment. Returns secret + otpauth URI once."""
        from funkwhale_api.users import totp as totp_mod

        user = request.user
        if not user.is_authenticated:
            return Response(status=403)
        if not totp_mod.is_password_user(user):
            return Response(
                {
                    "error": "sso_only",
                    "detail": "SSO-only accounts do not use password 2FA.",
                },
                status=400,
            )
        if totp_mod.is_totp_enabled(user):
            return Response(
                {
                    "error": "already_enabled",
                    "detail": "Two-factor authentication is already enabled. "
                    "Disable it before setting up a new authenticator.",
                },
                status=400,
            )

        secret = totp_mod.generate_base32_secret()
        protected = totp_mod.protect_totp_secret(secret)
        device, _created = models.TotpDevice.objects.update_or_create(
            user=user,
            defaults={
                "secret": protected,
                "confirmed": False,
                "confirmed_at": None,
                "last_used_step": None,
            },
        )
        # update_or_create with defaults may not replace secret if we only
        # want a fresh secret when restarting — force-save above via defaults.
        device.secret = protected
        device.confirmed = False
        device.confirmed_at = None
        device.last_used_step = None
        device.save()

        account = user.email or user.username
        uri = totp_mod.provisioning_uri(secret, account_name=account)
        return Response(
            {
                "secret": secret,
                "otpauth_uri": uri,
                "algorithm": "SHA1",
                "digits": totp_mod.TOTP_DIGITS,
                "period": totp_mod.TOTP_PERIOD,
            },
            status=200,
        )

    @extend_schema(operation_id="totp_confirm")
    @action(
        methods=["post"],
        detail=False,
        url_path="me/2fa/confirm",
        url_name="me-2fa-confirm",
        required_scope="security",
    )
    def totp_confirm(self, request, *args, **kwargs):
        """Confirm TOTP setup with a code from the authenticator app."""
        from django.db import transaction
        from django.utils import timezone

        from funkwhale_api.users import totp as totp_mod

        user = request.user
        if not user.is_authenticated:
            return Response(status=403)

        code = (request.data.get("code") or request.data.get("totp_code") or "").strip()
        if not code:
            return Response(
                {"error": "missing_code", "detail": "Authenticator code is required."},
                status=400,
            )

        with transaction.atomic():
            try:
                device = models.TotpDevice.objects.select_for_update().get(user=user)
            except models.TotpDevice.DoesNotExist:
                return Response(
                    {
                        "error": "setup_required",
                        "detail": "Call setup first to generate a secret.",
                    },
                    status=400,
                )
            if device.confirmed:
                return Response(
                    {
                        "error": "already_enabled",
                        "detail": "Two-factor authentication is already enabled.",
                    },
                    status=400,
                )
            ok, step = totp_mod.verify_totp(
                totp_mod.reveal_totp_secret(device.secret), code
            )
            if not ok:
                return Response(
                    {
                        "error": "invalid_totp",
                        "detail": "Invalid authenticator code. Try again.",
                    },
                    status=400,
                )
            device.confirmed = True
            device.confirmed_at = timezone.now()
            device.last_used_step = step
            device.save(
                update_fields=["confirmed", "confirmed_at", "last_used_step"]
            )
            codes = totp_mod.generate_recovery_codes()
            totp_mod.store_recovery_codes(user, codes)

        return Response(
            {
                "enabled": True,
                "recovery_codes": codes,
                "detail": "Save these recovery codes in a safe place. "
                "They will not be shown again.",
            },
            status=200,
        )

    @extend_schema(operation_id="totp_disable")
    @action(
        methods=["post", "delete"],
        detail=False,
        url_path="me/2fa/disable",
        url_name="me-2fa-disable",
        required_scope="security",
    )
    def totp_disable(self, request, *args, **kwargs):
        """Disable TOTP. Requires current password and a valid TOTP/recovery code."""
        from funkwhale_api.users import totp as totp_mod

        user = request.user
        if not user.is_authenticated:
            return Response(status=403)

        if totp_mod.force_2fa_enabled() and totp_mod.is_password_user(user):
            return Response(
                {
                    "error": "force_2fa",
                    "detail": "This instance requires two-factor authentication. "
                    "You cannot disable it.",
                },
                status=403,
            )

        if not totp_mod.is_totp_enabled(user):
            return Response(
                {"error": "not_enabled", "detail": "Two-factor authentication is not enabled."},
                status=400,
            )

        code = (
            request.data.get("code")
            or request.data.get("totp_code")
            or request.data.get("recovery_code")
            or ""
        )
        code = str(code).strip()
        challenge_id = str(request.data.get("challenge_id") or "").strip()
        client_nonce = str(request.data.get("client_nonce") or "").strip()
        client_proof = str(request.data.get("client_proof") or "").strip()
        upgrade = (
            request.data.get("upgrade_password")
            or request.data.get("upgradePassword")
            or ""
        )

        if not code or not challenge_id or not client_proof:
            return Response(
                {
                    "error": "missing_credentials",
                    "detail": (
                        "Password confirmation challenge (challenge_id, "
                        "client_proof) and authenticator (or recovery) code "
                        "are required."
                    ),
                },
                status=400,
            )

        from funkwhale_api.users.password_transport import (
            verify_password_confirm_proof,
        )

        if not verify_password_confirm_proof(
            user,
            challenge_id=challenge_id,
            client_nonce=client_nonce,
            client_proof=client_proof,
            upgrade_password=str(upgrade) if upgrade is not None else "",
        ):
            return Response(
                {"error": "invalid_password", "detail": "Invalid password."},
                status=400,
            )

        from django.db import transaction

        with transaction.atomic():
            if not totp_mod.verify_user_totp(user, code):
                return Response(
                    {
                        "error": "invalid_totp",
                        "detail": "Invalid authenticator or recovery code.",
                    },
                    status=400,
                )
            models.TotpDevice.objects.filter(user=user).delete()
            models.TotpRecoveryCode.objects.filter(user=user).delete()

        return Response(status=204)

    def update(self, request, *args, **kwargs):
        if not self.request.user.username == kwargs.get("username"):
            return Response(status=403)
        return super().update(request, *args, **kwargs)

    def partial_update(self, request, *args, **kwargs):
        if not self.request.user.username == kwargs.get("username"):
            return Response(status=403)
        return super().partial_update(request, *args, **kwargs)


@extend_schema(operation_id="login")
@action(methods=["post"], detail=False)
def login(request):
    throttling.check_request(request, "login")
    if request.method != "POST":
        return http.HttpResponse(status=405)
    data = request.POST if request.POST else getattr(request, "data", request.POST)
    serializer = serializers.LoginSerializer(
        data=data, context={"request": request}
    )
    if not serializer.is_valid():
        return http.HttpResponse(
            json.dumps(serializer.errors), status=400, content_type="application/json"
        )
    serializer.save(request)
    csrf.rotate_token(request)
    token = csrf.get_token(request)
    response = http.HttpResponse(status=200)
    response.set_cookie("csrftoken", token, max_age=None)
    return response


def _first_value(value):
    """Unwrap single-element lists from form multi-values."""
    if isinstance(value, (list, tuple)):
        return value[0] if value else ""
    return value


def _extract_credentials(request):
    """Pull username/password from raw body JSON, DRF parsers, or form data.

    Prefer ``request.body`` so we are not dependent on content-type quirks from
    browser clients (Flutter web / Dio sometimes send unexpected headers).
    """
    raw = {}
    body_source = "none"
    content_type = ""
    try:
        content_type = (getattr(request, "content_type", None) or "")[:120]
    except Exception:
        content_type = ""

    # 1) Raw body (most reliable for JSON SPAs)
    try:
        body = request.body or b""
    except Exception:
        body = b""
    if body:
        try:
            text = body.decode("utf-8-sig").strip()
            if text.startswith("{"):
                parsed = json.loads(text)
                if isinstance(parsed, dict):
                    raw = parsed
                    body_source = "body-json"
        except (UnicodeError, ValueError, TypeError):
            pass

    # 2) DRF request.data (JSON / form / multipart parsers)
    if not raw:
        data = getattr(request, "data", None)
        if data is not None:
            if isinstance(data, (bytes, str)):
                try:
                    if isinstance(data, bytes):
                        data = data.decode("utf-8-sig")
                    data = json.loads(data) if data else {}
                except (TypeError, ValueError, UnicodeError):
                    data = {}
            if hasattr(data, "dict"):
                data = data.dict()
            if isinstance(data, dict) and data:
                raw = data
                body_source = "request.data"

    # 3) Django POST (application/x-www-form-urlencoded)
    if not raw:
        post = getattr(request, "POST", None)
        if post:
            raw = post.dict() if hasattr(post, "dict") else dict(post)
            if raw:
                body_source = "request.POST"

    if not isinstance(raw, dict):
        raw = {}

    username = _first_value(
        raw.get("username") or raw.get("email") or raw.get("login") or ""
    )
    password = _first_value(raw.get("password") or "")
    if isinstance(username, str):
        username = username.strip()
    else:
        username = str(username).strip() if username is not None else ""
    # Never strip passwords — trailing spaces can be intentional.
    if not isinstance(password, str):
        password = str(password) if password is not None else ""

    meta = {
        "body_source": body_source,
        "content_type": content_type,
        "body_len": len(body) if isinstance(body, (bytes, bytearray)) else 0,
        "keys": list(raw.keys()),
        "username_len": len(username),
        "password_len": len(password),
    }
    return username, password, raw, meta


def _find_user(username: str):
    """Resolve local user by username, User.email, or allauth EmailAddress."""
    User = get_user_model()
    qs = User.objects.all().for_auth()
    user = (
        qs.filter(username__iexact=username).first()
        or qs.filter(email__iexact=username).first()
    )
    if user is not None:
        return user
    # User.email can lag behind allauth's EmailAddress table.
    try:
        from allauth.account.models import EmailAddress

        ea = (
            EmailAddress.objects.filter(email__iexact=username)
            .select_related("user")
            .first()
        )
        if ea is not None:
            return qs.filter(pk=ea.user_id).first()
    except Exception:
        logger.exception("token_login EmailAddress lookup failed")
    return None


def _log_token_login(msg, *args):
    """Log to both app and django.request so it shows next to Bad Request lines.

    H8: never interpolate raw usernames/emails/passwords into *args.
    """
    logger.warning(msg, *args)
    logging.getLogger("django.request").warning(msg, *args)


def _safe_login_meta(meta):
    """Return non-identifying request meta for login logs (H8)."""
    if not isinstance(meta, dict):
        return {}
    return {
        k: meta.get(k)
        for k in ("body_source", "content_type", "username_len", "password_len")
        if k in meta
    }


def _extract_login_proof_fields(raw: dict) -> dict:
    """Pull challenge/proof fields from a parsed login body."""
    if not isinstance(raw, dict):
        return {}

    def _s(key):
        val = raw.get(key)
        if val is None:
            return ""
        return str(val).strip()

    return {
        "challenge_id": _s("challenge_id"),
        "client_nonce": _s("client_nonce"),
        "client_proof": _s("client_proof"),
        "server_nonce": _s("server_nonce"),
    }


@extend_schema(
    operation_id="password_confirm_challenge",
    description=(
        "Issue a one-time SCRAM challenge for authenticated password step-up "
        "(change password/email, deactivate, disable 2FA). Never send the "
        "account password or a static transport digest on those endpoints."
    ),
)
@api_view(["POST"])
def password_confirm_challenge(request):
    """POST (authenticated) → one-time challenge for password re-verification."""
    from funkwhale_api.users.password_transport import (
        create_password_confirm_challenge,
    )

    user = getattr(request, "user", None)
    if user is None or not user.is_authenticated:
        return Response(status=403)
    if not user.has_usable_password():
        return Response(
            {
                "error": "no_password",
                "detail": "This account has no password to confirm.",
            },
            status=400,
        )
    throttling.check_request(request, "login")
    challenge = create_password_confirm_challenge(user)
    return Response(challenge)


@extend_schema(
    operation_id="token_login_challenge",
    description=(
        "Issue a one-time salted login challenge for first-party password login. "
        "Clients must complete POST /api/v1/users/token/ with a per-request proof "
        "bound to this challenge (SCRAM-like). Never send the account password or "
        "a static digest alone."
    ),
)
@api_view(["POST"])
@permission_classes([AllowAny])
@authentication_classes([])
def token_login_challenge(request):
    """POST username → one-time challenge parameters for token_login."""
    from funkwhale_api.users.password_transport import create_login_challenge

    throttling.check_request(request, "login")
    username, _password, raw, meta = _extract_credentials(request)
    if not username:
        # Allow username-only body (password field empty).
        if isinstance(raw, dict):
            username = str(
                raw.get("username") or raw.get("email") or raw.get("login") or ""
            ).strip()

    if not username:
        return Response(
            {
                "error": "missing_username",
                "detail": "Username is required to start login.",
            },
            status=400,
        )

    user = _find_user(username)
    challenge = create_login_challenge(username, user=user)
    # H8: do not log whether the username exists (user enumeration).
    _log_token_login(
        "token_login_challenge issued scheme=%s meta=%s",
        challenge.get("scheme"),
        _safe_login_meta(meta),
    )
    return Response(challenge)


@extend_schema(
    operation_id="token_login",
    description=(
        "First-party password login for Tayra. Requires a prior "
        "POST /api/v1/users/token/challenge/ and a per-request verifier: "
        "SCRAM-like client_proof (scram_v2), or for legacy password rows a "
        "v1 transport digest plus HMAC client_proof bound to the challenge "
        "(and optional upgrade_password to migrate storage to SCRAM). "
        "Returns OAuth access/refresh tokens, client credentials for refresh, "
        "and a scoped listen_token for media URLs (?token=)."
    ),
)
@api_view(["POST"])
@permission_classes([AllowAny])
@authentication_classes([])
def token_login(request):
    """POST username + challenge-bound proof → OAuth tokens."""
    from funkwhale_api.users.password_transport import (
        clear_login_failures,
        is_login_locked,
        is_scram_hash,
        is_transport_password_hash,
        pop_login_challenge,
        record_login_failure,
        upgrade_password_matches_legacy_digest,
        verify_client_proof,
        verify_legacy_client_proof,
    )

    throttling.check_request(request, "login")
    username, password, raw, meta = _extract_credentials(request)
    proof = _extract_login_proof_fields(raw)
    challenge_id = proof.get("challenge_id") or ""
    client_nonce = proof.get("client_nonce") or ""
    client_proof = proof.get("client_proof") or ""

    if not username:
        _log_token_login(
            "token_login missing username meta=%s",
            _safe_login_meta(meta),
        )
        return Response(
            {
                "error": "missing_credentials",
                "detail": "Username and a challenge-bound proof are required.",
                "non_field_errors": [
                    "Username and a challenge-bound proof are required."
                ],
            },
            status=400,
        )

    # M6: per-username lockout (same counter for missing/present accounts).
    if is_login_locked(username):
        _log_token_login(
            "token_login locked meta=%s",
            _safe_login_meta(meta),
        )
        return Response(
            {
                "error": "invalid_credentials",
                "detail": "Unable to log in with provided credentials",
                "non_field_errors": ["Unable to log in with provided credentials"],
            },
            status=400,
        )

    if not challenge_id:
        _log_token_login(
            "token_login missing challenge meta=%s",
            _safe_login_meta(meta),
        )
        return Response(
            {
                "error": "missing_challenge",
                "detail": (
                    "Login requires a one-time challenge from "
                    "POST /api/v1/users/token/challenge/."
                ),
                "non_field_errors": ["Login challenge is required."],
            },
            status=400,
        )

    challenge = pop_login_challenge(challenge_id)
    if challenge is None:
        _log_token_login(
            "token_login invalid_or_expired_challenge meta=%s",
            _safe_login_meta(meta),
        )
        return Response(
            {
                "error": "invalid_challenge",
                "detail": "Login challenge is invalid or expired. Request a new one.",
                "non_field_errors": ["Login challenge is invalid or expired."],
            },
            status=400,
        )

    # Challenge is bound to the username that requested it.
    challenge_user = (challenge.get("username") or "").strip()
    if challenge_user.lower() != username.lower():
        _log_token_login(
            "token_login challenge_username_mismatch meta=%s",
            _safe_login_meta(meta),
        )
        return Response(
            {
                "error": "invalid_challenge",
                "detail": "Login challenge does not match this username.",
                "non_field_errors": ["Login challenge does not match this username."],
            },
            status=400,
        )

    server_nonce = challenge.get("server_nonce") or ""
    scheme = challenge.get("scheme") or "scram_v2"

    user = _find_user(username)
    password_ok = False
    usable = None
    if user is not None:
        usable = user.has_usable_password()

        if usable and scheme == "scram_v2" and is_scram_hash(user.password):
            if not client_nonce or not client_proof:
                _log_token_login(
                    "token_login missing proof meta=%s",
                    _safe_login_meta(meta),
                )
                return Response(
                    {
                        "error": "missing_proof",
                        "detail": (
                            "SCRAM login requires client_nonce and client_proof."
                        ),
                        "non_field_errors": ["Login proof is required."],
                    },
                    status=400,
                )
            password_ok = verify_client_proof(
                user.password,
                username=username,
                client_nonce=client_nonce,
                server_nonce=server_nonce,
                client_proof_hex=client_proof,
            )
        elif usable and scheme == "legacy_v1":
            # Legacy django_hash(v1_digest) rows. Preferred path: account
            # password as upgrade_password (one TLS hop, then SCRAM). Digest +
            # HMAC path kept for older clients. Never advertise legacy_v1 on
            # the public challenge (M1).
            upgrade = ""
            if isinstance(raw, dict):
                upgrade = (
                    raw.get("upgrade_password")
                    or raw.get("upgradePassword")
                    or ""
                )
            upgrade = str(upgrade) if upgrade is not None else ""

            if upgrade and user.check_password(upgrade):
                try:
                    user.set_password(upgrade)
                    fields = ["password", "secret_key"]
                    if user.subsonic_api_token:
                        fields.append("subsonic_api_token")
                    user.save(update_fields=fields)
                    password_ok = True
                    _log_token_login(
                        "token_login legacy upgraded to SCRAM user_id=%s",
                        user.pk,
                    )
                except Exception:
                    logger.exception(
                        "token_login legacy SCRAM upgrade failed user_id=%s",
                        user.pk,
                    )
                    return Response(
                        {
                            "error": "token_issue_failed",
                            "detail": (
                                "Could not upgrade password storage. Try again."
                            ),
                        },
                        status=500,
                    )
            elif is_transport_password_hash(password) and client_nonce and client_proof:
                digest_ok = user.check_password(password)
                proof_ok = verify_legacy_client_proof(
                    password,
                    client_proof,
                    username=username,
                    client_nonce=client_nonce,
                    server_nonce=server_nonce,
                    challenge_id=challenge_id,
                )
                upgrade_ok = bool(
                    upgrade
                    and upgrade_password_matches_legacy_digest(upgrade, password)
                )
                password_ok = bool(digest_ok and proof_ok and upgrade_ok)
                if password_ok:
                    try:
                        user.set_password(upgrade)
                        fields = ["password", "secret_key"]
                        if user.subsonic_api_token:
                            fields.append("subsonic_api_token")
                        user.save(update_fields=fields)
                        _log_token_login(
                            "token_login legacy upgraded to SCRAM user_id=%s",
                            user.pk,
                        )
                    except Exception:
                        logger.exception(
                            "token_login legacy SCRAM upgrade failed user_id=%s",
                            user.pk,
                        )
                        return Response(
                            {
                                "error": "token_issue_failed",
                                "detail": (
                                    "Could not upgrade password storage. Try again."
                                ),
                            },
                            status=500,
                        )
            else:
                password_ok = False
        elif usable:
            # Scheme/storage mismatch (e.g. race after password change).
            password_ok = False

    # H8: single generic failure for wrong password, missing user, disabled,
    # and unverified-email accounts — do not reveal account state or 2FA.
    # TOTP is still returned only after a correct password (protocol need).
    if user is None or not password_ok:
        record_login_failure(username)
        _log_token_login(
            "token_login invalid_credentials scheme=%s meta=%s",
            scheme,
            _safe_login_meta(meta),
        )
        return Response(
            {
                "error": "invalid_credentials",
                "detail": "Unable to log in with provided credentials",
                "non_field_errors": ["Unable to log in with provided credentials"],
            },
            status=400,
        )

    if not user.is_active or user.should_verify_email():
        # Same wire response as bad credentials (no account-state oracle).
        record_login_failure(username)
        _log_token_login(
            "token_login rejected_account_state scheme=%s meta=%s",
            scheme,
            _safe_login_meta(meta),
        )
        return Response(
            {
                "error": "invalid_credentials",
                "detail": "Unable to log in with provided credentials",
                "non_field_errors": ["Unable to log in with provided credentials"],
            },
            status=400,
        )

    clear_login_failures(username)

    # TOTP second factor when the user has confirmed an authenticator.
    # Returning totp_required after a correct password is required for the
    # MFA flow; it does not distinguish users who do not exist or have a
    # wrong password (those already received invalid_credentials).
    from funkwhale_api.users import totp as totp_mod

    if totp_mod.is_totp_enabled(user):
        mfa_token = totp_mod.create_mfa_token(user.pk)
        _log_token_login(
            "token_login totp_required meta=%s",
            _safe_login_meta(meta),
        )
        return Response(
            {
                "error": "totp_required",
                "code": "totp_required",
                "detail": "Two-factor authentication code required.",
                "mfa_token": mfa_token,
            },
            status=401,
        )

    return _issue_token_response(user, meta)


def _issue_token_response(user, meta=None):
    """Issue OAuth tokens and attach totp_setup_required when force_2fa is on."""
    from funkwhale_api.users import first_party
    from funkwhale_api.users import totp as totp_mod

    try:
        payload = first_party.issue_user_tokens(user)
    except Exception:
        logger.exception("token_login failed to issue tokens user_id=%s", user.pk)
        return Response(
            {
                "error": "token_issue_failed",
                "detail": "Could not issue tokens. Try again later.",
            },
            status=500,
        )

    payload["totp_enabled"] = totp_mod.is_totp_enabled(user)
    payload["totp_setup_required"] = totp_mod.needs_totp_setup(user)

    logger.info(
        "token_login success user_id=%s meta=%s totp_setup_required=%s",
        user.pk,
        _safe_login_meta(meta),
        payload["totp_setup_required"],
    )
    return Response(payload, status=200)


@extend_schema(
    operation_id="token_login_2fa",
    description=(
        "Complete first-party password login after TOTP challenge. "
        "Send the mfa_token from the totp_required response plus a 6-digit "
        "authenticator code (or a recovery code)."
    ),
)
@api_view(["POST"])
@permission_classes([AllowAny])
@authentication_classes([])
def token_login_2fa(request):
    """POST mfa_token + totp_code → OAuth tokens."""
    from funkwhale_api.users import totp as totp_mod

    throttling.check_request(request, "login")

    raw = {}
    if hasattr(request, "data") and request.data is not None:
        try:
            raw = dict(request.data)
        except Exception:
            raw = {}
    if not raw and request.body:
        try:
            raw = json.loads(request.body.decode("utf-8") or "{}")
        except Exception:
            raw = {}

    mfa_token = (raw.get("mfa_token") or raw.get("mfaToken") or "").strip()
    code = (
        raw.get("totp_code")
        or raw.get("totpCode")
        or raw.get("code")
        or raw.get("recovery_code")
        or ""
    )
    code = str(code).strip()

    if not mfa_token or not code:
        return Response(
            {
                "error": "missing_credentials",
                "detail": "Both mfa_token and totp_code are required.",
            },
            status=400,
        )

    # Peek without consuming so wrong codes can be retried within the TTL.
    user_id = totp_mod.load_mfa_token(mfa_token)
    if user_id is None:
        return Response(
            {
                "error": "invalid_mfa_token",
                "detail": "Invalid or expired two-factor challenge. Sign in again.",
            },
            status=400,
        )

    User = get_user_model()
    try:
        user = User.objects.all().for_auth().get(pk=user_id, is_active=True)
    except User.DoesNotExist:
        return Response(
            {"error": "invalid_mfa_token", "detail": "Invalid two-factor challenge."},
            status=400,
        )

    if not totp_mod.is_totp_enabled(user):
        return Response(
            {
                "error": "totp_not_enabled",
                "detail": "Two-factor authentication is not enabled for this account.",
            },
            status=400,
        )

    # M7: per-account lockout after repeated failed TOTP attempts (in addition
    # to the IP-based login throttle above).
    if totp_mod.is_totp_locked(user.pk):
        _log_token_login("token_login_2fa locked user_id=%s", user.pk)
        return Response(
            {
                "error": "totp_locked",
                "detail": (
                    "Too many failed two-factor attempts. "
                    "Try again later or use a recovery code after the lockout."
                ),
                "non_field_errors": [
                    "Too many failed two-factor attempts. Try again later."
                ],
            },
            status=429,
        )

    from django.db import transaction

    with transaction.atomic():
        if not totp_mod.verify_user_totp(user, code):
            locked = totp_mod.record_totp_failure(user.pk)
            _log_token_login(
                "token_login_2fa invalid_code user_id=%s locked=%s",
                user.pk,
                locked,
            )
            if locked:
                return Response(
                    {
                        "error": "totp_locked",
                        "detail": (
                            "Too many failed two-factor attempts. "
                            "Try again later."
                        ),
                        "non_field_errors": [
                            "Too many failed two-factor attempts. Try again later."
                        ],
                    },
                    status=429,
                )
            return Response(
                {
                    "error": "invalid_totp",
                    "detail": "Invalid authentication or recovery code.",
                    "non_field_errors": ["Invalid authentication or recovery code."],
                },
                status=400,
            )

    # Success: burn the MFA challenge so the same mfa_token cannot re-issue.
    if totp_mod.consume_mfa_token(mfa_token) is None:
        return Response(
            {
                "error": "invalid_mfa_token",
                "detail": "Invalid or expired two-factor challenge. Sign in again.",
            },
            status=400,
        )

    totp_mod.clear_totp_failures(user.pk)
    return _issue_token_response(user, meta="2fa")


@extend_schema(operation_id="logout")
@action(methods=["post"], detail=False)
def logout(request):
    if request.method != "POST":
        return http.HttpResponse(status=405)
    auth.logout(request)
    token = csrf.get_token(request)
    response = http.HttpResponse(status=200)
    response.set_cookie("csrftoken", token, max_age=None)
    return response
