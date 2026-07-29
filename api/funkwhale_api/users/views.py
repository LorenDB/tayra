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
    action = "password-change"


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
    """Log to both app and django.request so it shows next to Bad Request lines."""
    logger.warning(msg, *args)
    logging.getLogger("django.request").warning(msg, *args)


@extend_schema(
    operation_id="token_login",
    description=(
        "First-party password login for Tayra. The password field must be a "
        "domain-separated SHA-256 hex digest of the account password (see "
        "password_transport.hash_password_for_transport), not plaintext. "
        "Returns OAuth access/refresh tokens, client credentials for refresh, "
        "and a scoped listen_token for media URLs (?token=)."
    ),
)
@api_view(["POST"])
@permission_classes([AllowAny])
@authentication_classes([])
def token_login(request):
    """POST username + transport-hashed password → OAuth tokens."""
    from funkwhale_api.users.password_transport import is_transport_password_hash

    throttling.check_request(request, "login")
    username, password, raw, meta = _extract_credentials(request)

    if not username or not password:
        _log_token_login(
            "token_login missing credentials meta=%s username_empty=%s password_empty=%s",
            meta,
            not bool(username),
            not bool(password),
        )
        return Response(
            {
                "error": "missing_credentials",
                "detail": "Both username and password are required.",
                "non_field_errors": ["Both username and password are required."],
            },
            status=400,
        )

    if not is_transport_password_hash(password):
        _log_token_login(
            "token_login plaintext_password_rejected meta=%s password_len=%s",
            meta,
            len(password),
        )
        return Response(
            {
                "error": "password_not_hashed",
                "detail": (
                    "Password must be a SHA-256 hex digest "
                    "(tayra-login-v1 transport hash), not plaintext."
                ),
                "non_field_errors": [
                    "Password must be hashed client-side before login."
                ],
            },
            status=400,
        )

    user = _find_user(username)
    password_ok = False
    usable = None
    hasher = None
    if user is not None:
        usable = user.has_usable_password()
        password_ok = user.check_password(password) if usable else False
        # e.g. "pbkdf2_sha256" — helps spot missing hasher / corrupt hash
        if user.password and "$" in user.password:
            hasher = user.password.split("$", 1)[0]

    if user is None or not password_ok:
        # Second chance: full Django auth stack (LDAP, allauth, etc.).
        # Note: LDAP backends need the real password; this endpoint only
        # receives a transport digest, so LDAP users should use OAuth code flow.
        django_request = getattr(request, "_request", request)
        try:
            authed = auth.authenticate(
                request=django_request, username=username, password=password
            )
            # allauth username_email also accepts email= in some versions
            if authed is None and "@" in username:
                authed = auth.authenticate(
                    request=django_request, email=username, password=password
                )
        except authentication.UnverifiedEmail:
            _log_token_login(
                "token_login unverified email for login=%r meta=%s", username, meta
            )
            return Response(
                {
                    "error": "email_unverified",
                    "code": "email_unverified",
                    "detail": "Please verify your e-mail address before logging in.",
                    "non_field_errors": [
                        "Please verify your e-mail address before logging in."
                    ],
                },
                status=400,
            )
        if authed is None:
            user_count = get_user_model().objects.count()
            _log_token_login(
                "token_login invalid_credentials login=%r user_found=%s "
                "user_id=%s is_active=%s has_usable_password=%s hasher=%s "
                "user_count=%s meta=%s "
                "(if user_found=False check DATABASE_URL points at your existing DB; "
                "if has_usable_password=False check LDAP_ENABLED / set a local password; "
                "passwords set before transport hashing need a one-time reset)",
                username,
                user is not None,
                getattr(user, "pk", None),
                getattr(user, "is_active", None),
                usable,
                hasher,
                user_count,
                meta,
            )
            return Response(
                {
                    "error": "invalid_credentials",
                    "detail": "Unable to log in with provided credentials",
                    "non_field_errors": ["Unable to log in with provided credentials"],
                },
                status=400,
            )
        user = authed

    if not user.is_active:
        _log_token_login("token_login inactive user_id=%s", user.pk)
        return Response(
            {
                "error": "account_disabled",
                "detail": "This account was disabled",
                "non_field_errors": ["This account was disabled"],
            },
            status=400,
        )

    if user.should_verify_email():
        _log_token_login("token_login email not verified user_id=%s", user.pk)
        return Response(
            {
                "error": "email_unverified",
                "code": "email_unverified",
                "detail": "Please verify your e-mail address before logging in.",
                "non_field_errors": [
                    "Please verify your e-mail address before logging in."
                ],
            },
            status=400,
        )

    try:
        from funkwhale_api.users import first_party

        payload = first_party.issue_user_tokens(user)
    except Exception as exc:
        logger.exception("token_login failed to issue tokens user_id=%s", user.pk)
        return Response(
            {"error": "token_issue_failed", "detail": str(exc)},
            status=500,
        )

    logger.info(
        "token_login success user_id=%s username=%s meta=%s",
        user.pk,
        user.username,
        meta,
    )
    return Response(payload, status=200)


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
