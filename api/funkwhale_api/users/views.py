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


def _extract_credentials(request):
    """Pull username/password from JSON, form, or nested body."""
    raw = getattr(request, "data", None)
    if raw is None:
        raw = request.POST
    # Some clients (or proxies) double-encode JSON so DRF leaves a string body.
    if isinstance(raw, (bytes, str)):
        try:
            if isinstance(raw, bytes):
                raw = raw.decode("utf-8")
            raw = json.loads(raw) if raw else {}
        except (TypeError, ValueError, UnicodeError):
            raw = {}
    if hasattr(raw, "dict"):
        raw = raw.dict()
    if not isinstance(raw, dict):
        raw = {}
    # QueryDict / form multi-values may arrive as lists.
    def _first(value):
        if isinstance(value, (list, tuple)):
            return value[0] if value else ""
        return value

    username = _first(raw.get("username") or raw.get("email") or raw.get("login") or "")
    password = _first(raw.get("password") or "")
    if isinstance(username, str):
        username = username.strip()
    else:
        username = str(username).strip() if username is not None else ""
    # Never strip passwords — trailing spaces can be intentional.
    if not isinstance(password, str):
        password = str(password) if password is not None else ""
    return username, password, raw


def _find_user(username: str):
    User = get_user_model()
    qs = User.objects.all().for_auth()
    return (
        qs.filter(username__iexact=username).first()
        or qs.filter(email__iexact=username).first()
    )


@extend_schema(
    operation_id="token_login",
    description=(
        "First-party password login for Tayra. Returns OAuth access/refresh "
        "tokens, client credentials for refresh, and a scoped listen_token "
        "for media URLs (?token=)."
    ),
)
@api_view(["POST"])
@permission_classes([AllowAny])
@authentication_classes([])
def token_login(request):
    """POST username + password → OAuth tokens (no browser OAuth dance)."""
    throttling.check_request(request, "login")
    username, password, raw = _extract_credentials(request)

    if not username or not password:
        logger.warning(
            "token_login missing credentials keys=%s username_empty=%s password_empty=%s",
            list(raw.keys()) if isinstance(raw, dict) else type(raw),
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

    user = _find_user(username)
    password_ok = False
    if user is not None:
        password_ok = user.check_password(password)

    if user is None or not password_ok:
        # Second chance: full Django auth stack (LDAP, allauth, etc.)
        django_request = getattr(request, "_request", request)
        try:
            authed = auth.authenticate(
                request=django_request, username=username, password=password
            )
        except authentication.UnverifiedEmail:
            logger.warning("token_login unverified email for login=%r", username)
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
            logger.warning(
                "token_login failed login=%r user_found=%s has_usable_password=%s",
                username,
                user is not None,
                getattr(user, "has_usable_password", lambda: None)(),
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
        logger.warning("token_login inactive user_id=%s", user.pk)
        return Response(
            {
                "error": "account_disabled",
                "detail": "This account was disabled",
                "non_field_errors": ["This account was disabled"],
            },
            status=400,
        )

    if user.should_verify_email():
        logger.warning("token_login email not verified user_id=%s", user.pk)
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

    logger.info("token_login success user_id=%s username=%s", user.pk, user.username)
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
