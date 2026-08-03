import pycountry
from dynamic_preferences import types
from dynamic_preferences.registries import global_preferences_registry

from funkwhale_api.common import preferences as common_preferences

from . import models

moderation = types.Section("moderation")


@global_preferences_registry.register
class AllowListEnabled(types.BooleanPreference):
    section = moderation
    name = "allow_list_enabled"
    verbose_name = "Enable allow-listing"
    help_text = "If enabled, only interactions with explicitly allowed domains will be authorized."
    default = False


@global_preferences_registry.register
class AllowListPublic(types.BooleanPreference):
    section = moderation
    name = "allow_list_public"
    verbose_name = "Publish your allowed-domains list"
    help_text = (
        "If enabled, everyone will be able to retrieve the list of domains you allowed. "
        "This is useful on open setups, to help people decide if they want to join your pod, or to "
        "make your moderation policy public."
    )
    default = False


@global_preferences_registry.register
class UnauthenticatedReportTypes(common_preferences.StringListPreference):
    show_in_api = True
    section = moderation
    name = "unauthenticated_report_types"
    default = ["takedown_request", "illegal_content"]
    verbose_name = "Accountless report categories"
    help_text = "A list of categories for which external users (without an account) can submit a report"
    choices = models.REPORT_TYPES
    field_kwargs = {"choices": choices, "required": False}


@global_preferences_registry.register
class SignupApprovalEnabled(types.BooleanPreference):
    show_in_api = True
    section = moderation
    name = "signup_approval_enabled"
    verbose_name = "Enable manual sign-up validation"
    help_text = "If enabled, new registrations will go to a moderation queue and need to be reviewed by moderators."
    default = False


@global_preferences_registry.register
class Languages(common_preferences.StringListPreference):
    show_in_api = True
    section = moderation
    name = "languages"
    default = ["en"]
    verbose_name = "Moderation languages"
    help_text = (
        "The language(s) spoken by the server moderator(s). Set this to inform users "
        "what languages they should write reports and requests in."
    )
    choices = [(lang.alpha_3, lang.name) for lang in pycountry.languages]
    field_kwargs = {"choices": choices, "required": False}
