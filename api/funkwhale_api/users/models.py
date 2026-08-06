import datetime
import os
import secrets
import string
import uuid

from django.conf import settings
from django.contrib.auth.models import AbstractUser
from django.contrib.auth.models import UserManager as BaseUserManager
from django.db import models, transaction
from django.db.models import JSONField
from django.urls import reverse
from django.utils import timezone
from django.utils.translation import ugettext_lazy as _
from oauth2_provider import models as oauth2_models
from oauth2_provider import validators as oauth2_validators
from versatileimagefield.fields import VersatileImageField

from funkwhale_api.common import fields, preferences
from funkwhale_api.common import utils as common_utils
from funkwhale_api.common import validators as common_validators


def get_token(length=5):
    """Return a space-free passphrase from the wordlist (secrets CSPRNG)."""
    wordlist_path = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "wordlist.txt"
    )
    with open(wordlist_path) as f:
        words = [line.strip() for line in f if line.strip()]
    if not words:
        return secrets.token_urlsafe(16)
    phrase = "-".join(secrets.choice(words) for _ in range(length))
    return phrase.rstrip("-")


PERMISSIONS_CONFIGURATION = {
    "moderation": {
        "label": "Moderation",
        "help_text": "Block/mute/remove domains, users and content",
        "scopes": {
            "read:instance:policies",
            "write:instance:policies",
            "read:instance:accounts",
            "write:instance:accounts",
            "read:instance:domains",
            "write:instance:domains",
            "read:instance:reports",
            "write:instance:reports",
            "read:instance:requests",
            "write:instance:requests",
            "read:instance:notes",
            "write:instance:notes",
        },
    },
    "library": {
        "label": "Manage library",
        "help_text": "Manage library, delete files, tracks, artists, albums...",
        "scopes": {
            "read:instance:edits",
            "write:instance:edits",
            "read:instance:libraries",
            "write:instance:libraries",
        },
    },
    "settings": {
        "label": "Manage instance-level settings",
        "help_text": "",
        "scopes": {
            "read:instance:settings",
            "write:instance:settings",
            "read:instance:users",
            "write:instance:users",
            "read:instance:invitations",
            "write:instance:invitations",
        },
    },
}

PERMISSIONS = sorted(PERMISSIONS_CONFIGURATION.keys())


get_file_path = common_utils.ChunkedPath("users/avatars", preserve_file_name=False)


class UserQuerySet(models.QuerySet):
    def for_auth(self):
        """Optimization to avoid additional queries during authentication"""
        qs = self.all()
        return qs.prefetch_related("plugins", "emailaddress_set")


class UserManager(BaseUserManager):
    def get_queryset(self):
        return UserQuerySet(self.model, using=self._db)

    def get_by_natural_key(self, key):
        obj = BaseUserManager.get_by_natural_key(self.all().for_auth(), key)
        return obj


class User(AbstractUser):
    # First Name and Last Name do not cover name patterns
    # around the globe.
    name = models.CharField(_("Name of User"), blank=True, max_length=255)

    # updated on logout or password change, to invalidate JWT
    secret_key = models.UUIDField(default=uuid.uuid4, null=True)
    privacy_level = fields.get_privacy_field()

    # permissions
    permission_moderation = models.BooleanField(
        PERMISSIONS_CONFIGURATION["moderation"]["label"],
        help_text=PERMISSIONS_CONFIGURATION["moderation"]["help_text"],
        default=False,
    )
    permission_library = models.BooleanField(
        PERMISSIONS_CONFIGURATION["library"]["label"],
        help_text=PERMISSIONS_CONFIGURATION["library"]["help_text"],
        default=False,
    )
    permission_settings = models.BooleanField(
        PERMISSIONS_CONFIGURATION["settings"]["label"],
        help_text=PERMISSIONS_CONFIGURATION["settings"]["help_text"],
        default=False,
    )

    last_activity = models.DateTimeField(default=None, null=True, blank=True)

    invitation = models.ForeignKey(
        "Invitation",
        related_name="users",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
    )
    avatar = VersatileImageField(
        upload_to=get_file_path,
        null=True,
        blank=True,
        max_length=150,
        validators=[
            common_validators.ImageDimensionsValidator(min_width=50, min_height=50),
            common_validators.FileValidator(
                allowed_extensions=["png", "jpg", "jpeg", "gif"],
                max_size=1024 * 1024 * 2,
            ),
        ],
    )
    upload_quota = models.PositiveIntegerField(null=True, blank=True)

    avatar_attachment = models.ForeignKey(
        "common.Attachment",
        related_name="user_avatar",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
    )
    summary_obj = models.ForeignKey(
        "common.Content",
        related_name="user_summary",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
    )

    settings = JSONField(default=None, null=True, blank=True, max_length=50000)

    objects = UserManager()

    def __str__(self):
        return self.username

    def get_permissions(self, defaults=None):
        defaults = defaults or preferences.get("users__default_permissions")
        perms = {}
        for p in PERMISSIONS:
            v = self.is_superuser or getattr(self, f"permission_{p}") or p in defaults
            perms[p] = v
        return perms

    @property
    def all_permissions(self):
        return self.get_permissions()

    @transaction.atomic
    def set_settings(self, **settings):
        u = self.__class__.objects.select_for_update().get(pk=self.pk)
        if not u.settings:
            u.settings = {}
        for key, value in settings.items():
            u.settings[key] = value
        u.save(update_fields=["settings"])
        self.settings = u.settings

    def has_permissions(self, *perms, **kwargs):
        operator = kwargs.pop("operator", "and")
        if operator not in ["and", "or"]:
            raise ValueError(f"Invalid operator {operator}")
        permissions = self.get_permissions()
        checker = all if operator == "and" else any
        return checker([permissions[p] for p in perms])

    def get_absolute_url(self):
        return reverse("users:detail", kwargs={"username": self.username})

    def update_secret_key(self):
        self.secret_key = uuid.uuid4()
        return self.secret_key

    def revoke_auth_sessions(self):
        """Invalidate scoped tokens and OAuth grants so the user is logged out."""
        self.update_secret_key()
        self.save(update_fields=["secret_key"])
        self.users_grant.all().delete()
        self.users_accesstoken.all().delete()
        self.users_refreshtoken.all().delete()

    def deactivate(self):
        """Soft-disable the account and force logout (reversible by an admin)."""
        self.is_active = False
        self.update_secret_key()
        self.save(update_fields=["is_active", "secret_key"])
        self.users_grant.all().delete()
        self.users_accesstoken.all().delete()
        self.users_refreshtoken.all().delete()

    def set_password(self, raw_password):
        # Store a SCRAM verifier over the instance-bound transport secret so
        # first-party login can use a per-request proof (H2). Admin/CLI/forms
        # still pass the real account password.
        if raw_password is not None:
            from funkwhale_api.users.password_transport import create_scram_hash

            self.password = create_scram_hash(raw_password)
            self._password = raw_password
        else:
            super().set_password(raw_password)
        self.update_secret_key()

    def check_password(self, raw_password):
        """Accept plaintext (admin/CLI) or derived transport secret / legacy digest.

        SCRAM rows: verify via instance-bound PBKDF2 secret, or hex secret.
        Legacy rows: django_hash(v1_digest) dual-path (plaintext or digest).
        """
        from django.contrib.auth.hashers import check_password as django_check

        from funkwhale_api.users.password_transport import (
            hash_password_for_transport,
            is_scram_hash,
            is_transport_password_hash,
            transport_secret,
            verify_scram_secret,
        )

        if raw_password is None:
            return super().check_password(raw_password)

        encoded = self.password or ""

        # ── SCRAM storage (current scheme) ─────────────────────────────
        if is_scram_hash(encoded):
            # Plaintext account password only (admin/CLI/forms).
            # Do NOT accept the hex transport_secret here: that value is a
            # stable password-equivalent. Authenticated step-up uses a
            # one-time SCRAM proof via verify_password_confirm_proof (H2).
            if is_transport_password_hash(raw_password):
                return False
            return verify_scram_secret(encoded, transport_secret(raw_password))

        # ── Legacy django_hash(v1_digest) / plain django rows ───────────
        def setter(value_for_storage):
            # Hasher upgrade only. Do not convert legacy digests into SCRAM(D)
            # — that would break plaintext check_password. Full migration to
            # SCRAM happens on the next set_password(plaintext) call.
            super(User, self).set_password(value_for_storage)
            self._password = None
            self.save(update_fields=["password"])

        transported = hash_password_for_transport(raw_password)
        if django_check(transported, encoded, setter=setter):
            return True
        if django_check(raw_password, encoded, setter=setter):
            return True
        return False

    def get_activity_url(self):
        return settings.FUNKWHALE_URL + f"/@{self.username}"

    def record_activity(self):
        """
        Simply update the last_activity field if current value is too old
        than a threshold. This is useful to keep a track of inactive accounts.
        """
        current = self.last_activity
        delay = 60 * 15  # fifteen minutes
        now = timezone.now()

        if current is None or current < now - datetime.timedelta(seconds=delay):
            self.last_activity = now
            self.save(update_fields=["last_activity"])

    def get_upload_quota(self):
        return (
            self.upload_quota
            if self.upload_quota is not None
            else preferences.get("users__upload_quota")
        )

    def get_quota_status(self):
        from django.db.models import Sum

        from funkwhale_api.music.models import Upload

        data = {
            "total": 0,
            "draft": 0,
            "skipped": 0,
            "pending": 0,
            "finished": 0,
            "errored": 0,
        }
        rows = (
            Upload.objects.filter(library__owner=self)
            .values("import_status")
            .annotate(total=Sum("size"))
        )
        for row in rows:
            data[row["import_status"]] = row["total"] or 0
            data["total"] += row["total"] or 0
        max_ = self.get_upload_quota()
        return {
            "max": max_,
            "remaining": max(max_ - (data["total"] / 1000 / 1000), 0),
            "current": data["total"] / 1000 / 1000,
            "draft": data["draft"] / 1000 / 1000,
            "skipped": data["skipped"] / 1000 / 1000,
            "pending": data["pending"] / 1000 / 1000,
            "finished": data["finished"] / 1000 / 1000,
            "errored": data["errored"] / 1000 / 1000,
        }

    def get_channels_groups(self):
        groups = ["imports", "inbox"]
        groups = [f"user.{self.pk}.{g}" for g in groups]

        for permission, value in self.all_permissions.items():
            if value:
                groups.append(f"admin.{permission}")

        return groups

    def full_username(self) -> str:
        return self.username

    def get_avatar(self):
        return self.avatar_attachment

    @property
    def has_verified_primary_email(self) -> bool:
        return len(self.emailaddress_set.filter(primary=True, verified=True)) > 0

    def should_verify_email(self):
        if self.is_superuser:
            return False
        has_unverified_email = not self.has_verified_primary_email
        mandatory_verification = settings.ACCOUNT_EMAIL_VERIFICATION != "optional"
        return has_unverified_email and mandatory_verification


class OidcIdentity(models.Model):
    """Stable binding between an OIDC IdP subject and a local User.

    Matching on ``preferred_username`` alone is unsafe: a mutable or
    attacker-influenced claim can take over another local account. After the
    first successful SSO (or auto-create), logins resolve by ``(issuer, sub)``.
    """

    user = models.ForeignKey(
        User, related_name="oidc_identities", on_delete=models.CASCADE
    )
    # OpenID Provider issuer identifier (id_token ``iss``).
    issuer = models.CharField(max_length=512)
    # Subject identifier at that issuer (id_token ``sub``) — stable per account.
    subject = models.CharField(max_length=255)
    created_at = models.DateTimeField(auto_now_add=True)
    last_login_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["issuer", "subject"],
                name="users_oidcidentity_issuer_subject_uniq",
            ),
        ]
        indexes = [
            models.Index(fields=["user", "issuer"]),
        ]

    def __str__(self):
        return f"OidcIdentity(user={self.user_id}, iss={self.issuer!r}, sub={self.subject!r})"


class TotpDevice(models.Model):
    """Per-user TOTP authenticator (RFC 6238) for first-party password login."""

    user = models.OneToOneField(
        User, related_name="totp_device", on_delete=models.CASCADE
    )
    # Base32 shared secret, stored encrypted (enc2: Fernet via totp.protect_totp_secret).
    # Legacy enc1: (signed-only) and plaintext base32 rows are still readable
    # by reveal_totp_secret and re-encrypted on the next protect() write.
    secret = models.CharField(max_length=512)
    confirmed = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    confirmed_at = models.DateTimeField(null=True, blank=True)
    # Last accepted time-step counter (replay protection within window).
    last_used_step = models.BigIntegerField(null=True, blank=True)

    def __str__(self):
        state = "confirmed" if self.confirmed else "pending"
        return f"TotpDevice(user={self.user_id}, {state})"


class TotpRecoveryCode(models.Model):
    """Single-use recovery code (stored as SHA-256 of normalized form)."""

    user = models.ForeignKey(
        User, related_name="totp_recovery_codes", on_delete=models.CASCADE
    )
    code_hash = models.CharField(max_length=64, db_index=True)
    used_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=["user", "used_at"]),
        ]

    def __str__(self):
        return f"TotpRecoveryCode(user={self.user_id}, used={bool(self.used_at)})"


def generate_code(length=10):
    return "".join(secrets.choice(string.ascii_uppercase) for _ in range(length))


class InvitationQuerySet(models.QuerySet):
    def open(self, include=True):
        now = timezone.now()
        qs = self.annotate(_users=models.Count("users"))
        query = models.Q(_users=0, expiration_date__gt=now)
        if include:
            return qs.filter(query)
        return qs.exclude(query)


class Invitation(models.Model):
    creation_date = models.DateTimeField(default=timezone.now)
    expiration_date = models.DateTimeField()
    owner = models.ForeignKey(
        User, related_name="invitations", on_delete=models.CASCADE
    )
    invited_user = models.ForeignKey(
        User, related_name="user_invitations", null=True, on_delete=models.CASCADE
    )
    code = models.CharField(max_length=50, unique=True)

    objects = InvitationQuerySet.as_manager()

    def save(self, **kwargs):
        if not self.code:
            self.code = generate_code()
        if not self.expiration_date:
            self.expiration_date = self.creation_date + datetime.timedelta(
                days=settings.USERS_INVITATION_EXPIRATION_DAYS
            )

        return super().save(**kwargs)

    def set_invited_user(self, user):
        self.invited_user = user
        super().save()


class Application(oauth2_models.AbstractApplication):
    scope = models.TextField(blank=True)
    token = models.CharField(max_length=50, blank=True, null=True, unique=True)

    @property
    def normalized_scopes(self):
        from .oauth import permissions

        raw_scopes = set(self.scope.split(" ") if self.scope else [])
        return permissions.normalize(*raw_scopes)


# oob schemes are not supported yet in oauth toolkit
# (https://github.com/jazzband/django-oauth-toolkit/issues/235)
# so in the meantime, we override their validation to add support
OOB_SCHEMES = ["urn:ietf:wg:oauth:2.0:oob", "urn:ietf:wg:oauth:2.0:oob:auto"]


class CustomRedirectURIValidator(oauth2_validators.RedirectURIValidator):
    def __call__(self, value):
        if value in OOB_SCHEMES:
            return value
        return super().__call__(value)


oauth2_models.RedirectURIValidator = CustomRedirectURIValidator


class Grant(oauth2_models.AbstractGrant):
    pass


class AccessToken(oauth2_models.AbstractAccessToken):
    pass


class RefreshToken(oauth2_models.AbstractRefreshToken):
    pass


class IdToken(oauth2_models.AbstractIDToken):
    pass
