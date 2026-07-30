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


# ── OIDC SSO ────────────────────────────────────────────────────────────
# Non-empty string prefs override env; booleans OR with env (see oidc.config).


@global_preferences_registry.register
class OidcEnabled(types.BooleanPreference):
    show_in_api = True
    section = users
    name = "oidc_enabled"
    default = False
    verbose_name = "Enable OIDC single sign-on"
    help_text = (
        "Allow users to sign in with an external OpenID Connect identity "
        "provider. Password login remains available. Can also be enabled "
        "with the OIDC_ENABLED environment variable."
    )


@global_preferences_registry.register
class OidcDiscoveryUrl(types.StringPreference):
    section = users
    name = "oidc_discovery_url"
    default = ""
    verbose_name = "OIDC discovery URL"
    help_text = (
        "OpenID discovery document or issuer base URL, e.g. "
        "https://idp.example.com/.well-known/openid-configuration. "
        "Falls back to OIDC_DISCOVERY_URL when empty."
    )
    field_kwargs = {"required": False}


@global_preferences_registry.register
class OidcClientId(types.StringPreference):
    section = users
    name = "oidc_client_id"
    default = ""
    verbose_name = "OIDC client ID"
    help_text = "Client ID from your identity provider. Falls back to OIDC_CLIENT_ID."
    field_kwargs = {"required": False}


@global_preferences_registry.register
class OidcClientSecret(types.StringPreference):
    section = users
    name = "oidc_client_secret"
    default = ""
    verbose_name = "OIDC client secret"
    help_text = (
        "Client secret from your identity provider. Prefer the "
        "OIDC_CLIENT_SECRET environment variable in production. "
        "Falls back to that env var when this field is empty."
    )
    field_kwargs = {"required": False}


@global_preferences_registry.register
class OidcScopes(types.StringPreference):
    section = users
    name = "oidc_scopes"
    default = ""
    verbose_name = "OIDC scopes"
    help_text = (
        "Space-separated scopes (default: openid profile email). "
        "Falls back to OIDC_SCOPES when empty."
    )
    field_kwargs = {"required": False}


@global_preferences_registry.register
class OidcUsernameClaim(types.StringPreference):
    section = users
    name = "oidc_username_claim"
    default = ""
    verbose_name = "OIDC username claim"
    help_text = (
        "Claim used to match a local username (default: preferred_username). "
        "Falls back to OIDC_USERNAME_CLAIM when empty."
    )
    field_kwargs = {"required": False}


@global_preferences_registry.register
class OidcDisplayName(types.StringPreference):
    show_in_api = True
    section = users
    name = "oidc_display_name"
    default = ""
    verbose_name = "OIDC button label"
    help_text = (
        'Label for the login button (default: "SSO"). '
        "Falls back to OIDC_DISPLAY_NAME when empty."
    )
    field_kwargs = {"required": False}


@global_preferences_registry.register
class OidcAutoCreate(types.BooleanPreference):
    section = users
    name = "oidc_auto_create"
    default = False
    verbose_name = "Auto-create users on first OIDC login"
    help_text = (
        "When enabled, create a local account (no password) if the OIDC "
        "username does not match an existing user. When disabled, only "
        "existing users can sign in with SSO. Can also be set with "
        "OIDC_AUTO_CREATE."
    )


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
