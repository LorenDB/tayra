from django.core.exceptions import ImproperlyConfigured
from rest_framework import permissions

from funkwhale_api.common import preferences

from .. import models
from . import scopes


def normalize(*scope_ids):
    """
    Given an iterable containing scopes ids such as {read, write:playlists}
    will return a set containing all the leaf scopes (and no parent scopes)
    """
    final = set()
    for scope_id in scope_ids:
        try:
            scope_obj = scopes.SCOPES_BY_ID[scope_id]
        except KeyError:
            continue

        if scope_obj.children:
            final = final | {s.id for s in scope_obj.children}
        else:
            final.add(scope_obj.id)
    return final


def should_allow(required_scope, request_scopes):
    if not required_scope:
        return True

    if not request_scopes:
        return False

    return required_scope in normalize(*request_scopes)


METHOD_SCOPE_MAPPING = {
    "get": "read",
    "post": "write",
    "patch": "write",
    "put": "write",
    "delete": "write",
}


class ScopePermission(permissions.BasePermission):
    def has_permission(self, request, view):
        if request.method.lower() in ["options", "head"]:
            return True

        scope_config = getattr(view, "required_scope", "noopscope")
        anonymous_policy = getattr(view, "anonymous_policy", False)
        if anonymous_policy not in [True, False, "setting"]:
            raise ImproperlyConfigured(
                f"{anonymous_policy} is not a valid value for anonymous_policy"
            )
        if isinstance(scope_config, str):
            scope_config = {
                "read": f"read:{scope_config}",
                "write": f"write:{scope_config}",
            }
            action = METHOD_SCOPE_MAPPING[request.method.lower()]
            required_scope = scope_config[action]
        else:
            # we have a dict with explicit viewset actions / scopes
            required_scope = scope_config[view.action]

        token = request.auth

        if isinstance(token, models.AccessToken):
            return self.has_permission_token(token, required_scope)
        elif getattr(request, "scopes", None):
            # Application tokens (ApplicationTokenAuthentication): the
            # declared app scope must never grant more than the owner's
            # actual permissions, restricted to the OAuth app allowlist —
            # same contract as regular OAuth access tokens.
            if not request.user.is_authenticated:
                return False
            user_scopes = scopes.get_from_permissions(
                **request.user.get_permissions()
            )
            final_scopes = (
                user_scopes & normalize(*request.scopes) & scopes.OAUTH_APP_SCOPES
            )
            return should_allow(
                required_scope=required_scope, request_scopes=final_scopes
            )
        elif request.user.is_authenticated:
            user_scopes = scopes.get_from_permissions(**request.user.get_permissions())
            return should_allow(
                required_scope=required_scope, request_scopes=user_scopes
            )
        elif hasattr(request, "actor") and request.actor:
            # we use default anonymous scopes
            user_scopes = scopes.FEDERATION_REQUEST_SCOPES
            return should_allow(
                required_scope=required_scope, request_scopes=user_scopes
            )
        else:
            if anonymous_policy is False:
                return False
            if anonymous_policy == "setting" and preferences.get(
                "common__api_authentication_required"
            ):
                return False

            user_scopes = (
                getattr(view, "anonymous_scopes", set()) | scopes.ANONYMOUS_SCOPES
            )
            return should_allow(
                required_scope=required_scope, request_scopes=user_scopes
            )

    def has_permission_token(self, token, required_scope):
        if token.is_expired():
            return False

        if not token.user:
            return False

        user = token.user
        user_scopes = scopes.get_from_permissions(**user.get_permissions())
        token_scopes = set(token.scopes.keys())
        app_scopes = token.application.normalized_scopes if token.application else set()

        # Third-party OAuth apps are restricted to OAUTH_APP_SCOPES (no admin
        # /instance scopes). The first-party Tayra application is trusted and
        # may use privileged scopes the user actually holds (e.g.
        # instance:libraries when permission_library is true).
        if _is_first_party_application(token.application):
            final_scopes = user_scopes & normalize(*token_scopes) & app_scopes
        else:
            final_scopes = (
                user_scopes
                & normalize(*token_scopes)
                & app_scopes
                & scopes.OAUTH_APP_SCOPES
            )

        return should_allow(required_scope=required_scope, request_scopes=final_scopes)


def _is_first_party_application(application):
    """True for the system Tayra OAuth app (not third-party user-owned apps)."""
    if application is None:
        return False
    from funkwhale_api.users import first_party

    return (
        application.name == first_party.FIRST_PARTY_APP_NAME
        and getattr(application, "user_id", None) is None
    )
