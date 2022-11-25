import json

from allauth.account.adapter import get_adapter
from dj_rest_auth import views as rest_auth_views
from dj_rest_auth.registration import views as registration_views
from django import http
from django.contrib import auth
from django.middleware import csrf
from drf_spectacular.utils import extend_schema, extend_schema_view
from rest_framework import mixins, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from funkwhale_api.common import authentication, preferences, throttling

from . import models, serializers, tasks


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
    serializer = serializers.LoginSerializer(
        data=request.POST, context={"request": request}
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
