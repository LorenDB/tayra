from dynamic_preferences import types
from dynamic_preferences.registries import global_preferences_registry

from funkwhale_api.common import preferences as common_preferences

from . import models

users = types.Section("users")


@global_preferences_registry.register
class RegistrationEnabled(types.BooleanPreference):
    show_in_api = True
    section = users
    name = "registration_enabled"
    default = False
    verbose_name = "Open registrations to new users"
    help_text = "When enabled, new users will be able to register on this instance."


@global_preferences_registry.register
class DefaultPermissions(common_preferences.StringListPreference):
    show_in_api = True
    section = users
    name = "default_permissions"
    default = []
    verbose_name = "Default permissions"
    help_text = "A list of default preferences to give to all registered users."
    choices = [(k, c["label"]) for k, c in models.PERMISSIONS_CONFIGURATION.items()]
    field_kwargs = {"choices": choices, "required": False}


@global_preferences_registry.register
class UploadQuota(types.IntPreference):
    show_in_api = True
    section = users
    name = "upload_quota"
    default = 1000
    verbose_name = "Upload quota"
    help_text = "Default upload quota applied to each users, in MB. This can be overridden on a per-user basis."


# OIDC SSO is configured only via environment variables (OIDC_*), not instance
# preferences. See funkwhale_api.users.oidc.config and DEPLOY.md.


@global_preferences_registry.register
class Force2fa(types.BooleanPreference):
    show_in_api = True
    section = users
    name = "force_2fa"
    default = False
    verbose_name = "Require two-factor authentication (TOTP)"
    help_text = (
        "When enabled, all users who sign in with a password must configure "
        "an authenticator app (TOTP). SSO-only accounts (no local password) "
        "are exempt. Users cannot disable 2FA while this setting is on."
    )
