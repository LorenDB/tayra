import re

from allauth.account import models as allauth_models
from dj_rest_auth.registration.serializers import RegisterSerializer as RS
from dj_rest_auth.registration.serializers import get_adapter
from dj_rest_auth.serializers import PasswordResetConfirmSerializer as PRCS
from dj_rest_auth.serializers import PasswordResetSerializer as PRS
from django.contrib import auth
from django.contrib.auth.forms import PasswordResetForm
from django.core import validators
from django.utils.deconstruct import deconstructible
from django.utils.encoding import force_str
from django.utils.translation import gettext_lazy as _
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers
from rest_framework.exceptions import ValidationError

from funkwhale_api.activity import serializers as activity_serializers
from funkwhale_api.common import authentication as common_authentication
from funkwhale_api.common import models as common_models
from funkwhale_api.common import serializers as common_serializers
from funkwhale_api.common import utils as common_utils

from . import adapters
from . import authentication as users_authentication
from . import models


@deconstructible
class ASCIIUsernameValidator(validators.RegexValidator):
    regex = r"^[\w]+$"
    message = _(
        "Enter a valid username. This value may contain only English letters, "
        "numbers, and _ characters."
    )
    flags = re.ASCII


username_validators = [ASCIIUsernameValidator()]
NOOP = object()


class RegisterSerializer(RS):
    invitation = serializers.CharField(
        required=False, allow_null=True, allow_blank=True
    )

    def validate_invitation(self, value):
        if not value:
            return

        try:
            return models.Invitation.objects.open().get(code__iexact=value)
        except models.Invitation.DoesNotExist:
            raise serializers.ValidationError("Invalid invitation code")

    def validate(self, validated_data):
        data = super().validate(validated_data)
        # we create a fake user obj with validated data so we can validate
        # password properly (we have a password validator that requires
        # a user object)
        user = models.User(username=data["username"], email=data["email"])
        get_adapter().clean_password(data["password1"], user)
        return data

    def save(self, request):
        user = super().save(request)
        update_fields = []
        if self.validated_data.get("invitation"):
            user.invitation = self.validated_data.get("invitation")
            update_fields.append("invitation")
        if update_fields:
            user.save(update_fields=update_fields)

        return user


class UserActivitySerializer(activity_serializers.ModelSerializer):
    type = serializers.SerializerMethodField()
    name = serializers.CharField(source="username")
    local_id = serializers.CharField(source="username")

    class Meta:
        model = models.User
        fields = ["id", "local_id", "name", "type"]

    def get_type(self, obj):
        return "Person"


class UserBasicSerializer(serializers.ModelSerializer):
    avatar = common_serializers.AttachmentSerializer(
        source="get_avatar", allow_null=True
    )

    class Meta:
        model = models.User
        fields = ["id", "username", "name", "date_joined", "avatar"]


class UserWriteSerializer(serializers.ModelSerializer):
    summary = common_serializers.ContentSerializer(required=False, allow_null=True)
    avatar = common_serializers.RelatedField(
        "uuid",
        queryset=common_models.Attachment.objects.all().attached(False),
        serializer=None,
        queryset_filter=lambda qs, context: qs.filter(
            uploaded_by=context["request"].user
        ),
        write_only=True,
    )

    class Meta:
        model = models.User
        fields = [
            "name",
            "privacy_level",
            "avatar",
            "summary",
        ]

    def update(self, obj, validated_data):
        summary = validated_data.pop("summary", NOOP)
        avatar = validated_data.pop("avatar", NOOP)

        obj = super().update(obj, validated_data)

        if summary != NOOP:
            common_utils.attach_content(obj, "summary_obj", summary)
        if avatar != NOOP:
            obj.avatar_attachment = avatar
            obj.save(update_fields=["avatar_attachment"])
        return obj

    def to_representation(self, instance):
        r = super().to_representation(instance)
        r["avatar"] = common_serializers.AttachmentSerializer(
            instance.get_avatar()
        ).data
        return r


class UserReadSerializer(serializers.ModelSerializer):
    permissions = serializers.SerializerMethodField()
    full_username = serializers.SerializerMethodField()
    avatar = common_serializers.AttachmentSerializer(source="get_avatar")

    class Meta:
        model = models.User
        fields = [
            "id",
            "username",
            "full_username",
            "name",
            "email",
            "is_staff",
            "is_superuser",
            "permissions",
            "date_joined",
            "privacy_level",
            "avatar",
        ]

    def get_permissions(self, o):
        return o.get_permissions()

    @extend_schema_field(OpenApiTypes.STR)
    def get_full_username(self, o):
        return o.full_username()


class MeSerializer(UserReadSerializer):
    quota_status = serializers.SerializerMethodField()
    summary = serializers.SerializerMethodField()
    tokens = serializers.SerializerMethodField()
    totp_enabled = serializers.SerializerMethodField()
    totp_required = serializers.SerializerMethodField()
    has_usable_password = serializers.SerializerMethodField()

    class Meta(UserReadSerializer.Meta):
        fields = UserReadSerializer.Meta.fields + [
            "quota_status",
            "summary",
            "tokens",
            "settings",
            "totp_enabled",
            "totp_required",
            "has_usable_password",
        ]

    def get_quota_status(self, o):
        return o.get_quota_status()

    def get_summary(self, o):
        if not o.summary_obj_id:
            return
        return common_serializers.ContentSerializer(o.summary_obj).data

    def get_tokens(self, o):
        return {
            "listen": users_authentication.generate_scoped_token(
                user_id=o.pk, user_secret=o.secret_key, scopes=["read:libraries"]
            )
        }

    def get_totp_enabled(self, o):
        from funkwhale_api.users import totp as totp_mod

        return totp_mod.is_totp_enabled(o)

    def get_totp_required(self, o):
        from funkwhale_api.users import totp as totp_mod

        return totp_mod.needs_totp_setup(o)

    def get_has_usable_password(self, o):
        from funkwhale_api.users import totp as totp_mod

        return totp_mod.is_password_user(o)


class PasswordResetSerializer(PRS):
    password_reset_form_class = PasswordResetForm

    def get_email_options(self):
        return {"extra_email_context": adapters.get_email_context()}


class PasswordResetConfirmSerializer(PRCS):
    def validate(self, attrs):
        from allauth.account.forms import default_token_generator
        from django.utils.http import urlsafe_base64_decode as uid_decoder

        UserModel = auth.get_user_model()
        # Decode the uidb64 (allauth use base36) to uid to get User object
        try:
            uid = force_str(uid_decoder(attrs["uid"]))
            self.user = UserModel._default_manager.get(pk=uid)
        except (TypeError, ValueError, OverflowError, UserModel.DoesNotExist):
            raise ValidationError({"uid": [_("Invalid value")]})

        if not default_token_generator.check_token(self.user, attrs["token"]):
            raise ValidationError({"token": [_("Invalid value")]})

        self.custom_validation(attrs)
        # Construct SetPasswordForm instance
        self.set_password_form = self.set_password_form_class(
            user=self.user,
            data=attrs,
        )
        if not self.set_password_form.is_valid():
            raise serializers.ValidationError(self.set_password_form.errors)

        return attrs


def _verify_step_up_password(user, attrs):
    """Require a one-time SCRAM proof for password re-check (H2).

    Accepts ``challenge_id`` / ``client_nonce`` / ``client_proof`` from a prior
    ``POST /api/v1/users/password/confirm-challenge/``. Optional
    ``upgrade_password`` migrates legacy rows. Bare transport-hex or static
    password fields are no longer accepted on these endpoints.
    """
    from funkwhale_api.users.password_transport import verify_password_confirm_proof

    challenge_id = (attrs.get("challenge_id") or "").strip()
    client_nonce = (attrs.get("client_nonce") or "").strip()
    client_proof = (attrs.get("client_proof") or "").strip()
    upgrade = attrs.get("upgrade_password") or attrs.get("upgradePassword") or ""
    upgrade = str(upgrade) if upgrade is not None else ""

    if not challenge_id or not client_proof:
        raise serializers.ValidationError(
            {
                "challenge_id": (
                    "Password confirmation challenge required. "
                    "POST /api/v1/users/password/confirm-challenge/ first."
                )
            }
        )
    if not verify_password_confirm_proof(
        user,
        challenge_id=challenge_id,
        client_nonce=client_nonce,
        client_proof=client_proof,
        upgrade_password=upgrade,
    ):
        raise serializers.ValidationError(
            {"client_proof": "Invalid password confirmation"}
        )
    return attrs


class UserDeleteSerializer(serializers.Serializer):
    confirm = serializers.BooleanField()
    challenge_id = serializers.CharField(required=False, allow_blank=True)
    client_nonce = serializers.CharField(required=False, allow_blank=True)
    client_proof = serializers.CharField(required=False, allow_blank=True)
    upgrade_password = serializers.CharField(
        required=False, allow_blank=True, trim_whitespace=False
    )
    # Legacy field — rejected in validate (kept so clients get a clear error).
    password = serializers.CharField(
        required=False, allow_blank=True, trim_whitespace=False
    )

    def validate_confirm(self, value):
        if not value:
            raise serializers.ValidationError("Please confirm deletion")
        return value

    def validate(self, attrs):
        return _verify_step_up_password(self.instance, attrs)


class UserDeactivateSerializer(serializers.Serializer):
    """Confirm self-service account deactivation (soft-disable).

    Password step-up is required when the user has a usable password. SSO-only
    accounts only need ``confirm=true`` (client should still use type-to-confirm UX).
    """

    confirm = serializers.BooleanField()
    challenge_id = serializers.CharField(required=False, allow_blank=True)
    client_nonce = serializers.CharField(required=False, allow_blank=True)
    client_proof = serializers.CharField(required=False, allow_blank=True)
    upgrade_password = serializers.CharField(
        required=False, allow_blank=True, trim_whitespace=False
    )
    password = serializers.CharField(
        required=False, allow_blank=True, trim_whitespace=False
    )

    def validate_confirm(self, value):
        if not value:
            raise serializers.ValidationError("Please confirm deactivation")
        return value

    def validate(self, attrs):
        user = self.instance
        if user.has_usable_password():
            return _verify_step_up_password(user, attrs)
        return attrs


class LoginSerializer(serializers.Serializer):
    username = serializers.CharField()
    # Never strip passwords — trailing spaces can be intentional.
    password = serializers.CharField(trim_whitespace=False)

    def validate(self, data):
        request = self.context.get("request")
        # Django / allauth backends expect a Django HttpRequest, not DRF's Request.
        django_request = getattr(request, "_request", request)
        username = (data.get("username") or "").strip()
        password = data.get("password") or ""
        try:
            user = auth.authenticate(
                request=django_request, username=username, password=password
            )
        except common_authentication.UnverifiedEmail:
            raise serializers.ValidationError(
                {
                    "non_field_errors": [
                        "Please verify your e-mail address before logging in."
                    ],
                    "code": "email_unverified",
                }
            )

        # Fallback: case-insensitive username/email + check_password.
        # Covers edge cases where auth backends return None unexpectedly.
        if not user and username and password:
            User = auth.get_user_model()
            qs = User.objects.all().for_auth()
            candidate = (
                qs.filter(username__iexact=username).first()
                or qs.filter(email__iexact=username).first()
            )
            if candidate and candidate.check_password(password):
                if not candidate.is_active:
                    raise serializers.ValidationError("This account was disabled")
                if candidate.should_verify_email():
                    raise serializers.ValidationError(
                        {
                            "non_field_errors": [
                                "Please verify your e-mail address before logging in."
                            ],
                            "code": "email_unverified",
                        }
                    )
                user = candidate

        if not user:
            raise serializers.ValidationError(
                "Unable to log in with provided credentials"
            )

        if not user.is_active:
            raise serializers.ValidationError("This account was disabled")

        # Keep username/password in validated_data for callers that expect a dict;
        # attach the authenticated user for save().
        data = {"username": username, "password": password, "user": user}
        return data

    def save(self, request):
        return auth.login(request, self.validated_data["user"])


class TokenLoginSerializer(LoginSerializer):
    """
    Username/password → OAuth tokens for the first-party Tayra client.

    Prefer this over session login + authorization-code for SPA and native apps.
    """

    def save(self, request=None):
        # Parent save() creates a session; token login does not need one.
        from funkwhale_api.users import first_party

        user = self.validated_data["user"]
        return first_party.issue_user_tokens(user)


class UserChangeEmailSerializer(serializers.Serializer):
    email = serializers.EmailField()
    challenge_id = serializers.CharField(required=False, allow_blank=True)
    client_nonce = serializers.CharField(required=False, allow_blank=True)
    client_proof = serializers.CharField(required=False, allow_blank=True)
    upgrade_password = serializers.CharField(
        required=False, allow_blank=True, trim_whitespace=False
    )
    password = serializers.CharField(
        required=False, allow_blank=True, trim_whitespace=False
    )

    def validate_email(self, value):
        if (
            allauth_models.EmailAddress.objects.filter(email__iexact=value)
            .exclude(user=self.context["user"])
            .exists()
        ):
            raise serializers.ValidationError("This e-mail address is already in use")
        return value

    def validate(self, attrs):
        return _verify_step_up_password(self.instance, attrs)

    def save(self, request):
        current, _ = allauth_models.EmailAddress.objects.get_or_create(
            user=request.user,
            email=request.user.email,
            defaults={"verified": False, "primary": True},
        )
        current.change(request, self.validated_data["email"], confirm=True)


class PasswordChangeSerializer(serializers.Serializer):
    """Change password using a one-time SCRAM step-up proof (H2)."""

    challenge_id = serializers.CharField()
    client_nonce = serializers.CharField()
    client_proof = serializers.CharField()
    new_password1 = serializers.CharField(trim_whitespace=False)
    new_password2 = serializers.CharField(trim_whitespace=False)
    upgrade_password = serializers.CharField(
        required=False, allow_blank=True, trim_whitespace=False
    )

    def validate(self, attrs):
        if attrs.get("new_password1") != attrs.get("new_password2"):
            raise serializers.ValidationError(
                {"new_password2": "The two password fields didn't match."}
            )
        user = self.context["request"].user
        _verify_step_up_password(user, attrs)
        # Run Django password validators on the new password.
        from django.contrib.auth.password_validation import validate_password
        from django.core.exceptions import ValidationError as DjangoValidationError

        try:
            validate_password(attrs["new_password1"], user=user)
        except DjangoValidationError as exc:
            raise serializers.ValidationError({"new_password1": list(exc.messages)})
        return attrs

    def save(self):
        user = self.context["request"].user
        user.set_password(self.validated_data["new_password1"])
        user.save()
        return user
