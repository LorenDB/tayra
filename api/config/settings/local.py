# -*- coding: utf-8 -*-
"""
Local settings

- Run in Debug mode
- Use console backend for e-mails
- Add Django Debug Toolbar
- Add django-extensions as app
"""

from .common import *  # noqa
from funkwhale_api import __version__ as funkwhale_version
from drf_spectacular.contrib.django_oauth_toolkit import OpenApiAuthenticationExtension


# DEBUG
# ------------------------------------------------------------------------------
DEBUG = env.bool("DJANGO_DEBUG", default=True)
FORCE_HTTPS_URLS = env.bool("FORCE_HTTPS_URLS", default=False)
TEMPLATES[0]["OPTIONS"]["debug"] = DEBUG

# SECRET CONFIGURATION
# ------------------------------------------------------------------------------
# See: https://docs.djangoproject.com/en/dev/ref/settings/#secret-key
# Note: This key only used for development and testing.
SECRET_KEY = env(
    "DJANGO_SECRET_KEY", default="mc$&b=5j#6^bv7tld1gyjp2&+^-qrdy=0sw@r5sua*1zp4fmxc"
)

# Mail settings
# ------------------------------------------------------------------------------
EMAIL_HOST = "localhost"
EMAIL_PORT = 1025

# django-debug-toolbar
# ------------------------------------------------------------------------------

# INTERNAL_IPS = ('127.0.0.1', '10.0.2.2',)

DEBUG_TOOLBAR_CONFIG = {
    "DISABLE_PANELS": ["debug_toolbar.panels.redirects.RedirectsPanel"],
    "SHOW_TEMPLATE_CONTEXT": True,
    "SHOW_TOOLBAR_CALLBACK": lambda request: "debug" in request.GET,
    "JQUERY_URL": "/staticfiles/admin/js/vendor/jquery/jquery.js",
}
# DEBUG_TOOLBAR_PANELS = [
#     'debug_toolbar.panels.versions.VersionsPanel',
#     'debug_toolbar.panels.timer.TimerPanel',
#     'debug_toolbar.panels.settings.SettingsPanel',
#     'debug_toolbar.panels.headers.HeadersPanel',
#     'debug_toolbar.panels.request.RequestPanel',
#     'debug_toolbar.panels.sql.SQLPanel',
#     'debug_toolbar.panels.staticfiles.StaticFilesPanel',
#     'debug_toolbar.panels.templates.TemplatesPanel',
#     'debug_toolbar.panels.cache.CachePanel',
#     'debug_toolbar.panels.signals.SignalsPanel',
#     'debug_toolbar.panels.logging.LoggingPanel',
#     'debug_toolbar.panels.redirects.RedirectsPanel',
#     'debug_toolbar.panels.profiling.ProfilingPanel',
#     'debug_toolbar_line_profiler.panel.ProfilingPanel'
# ]

DEBUG_TOOLBAR_PANELS = [
    # 'debug_toolbar.panels.versions.VersionsPanel',
    "debug_toolbar.panels.timer.TimerPanel",
    "debug_toolbar.panels.settings.SettingsPanel",
    "debug_toolbar.panels.headers.HeadersPanel",
    # 'debug_toolbar.panels.request.RequestPanel',
    "debug_toolbar.panels.sql.SQLPanel",
    # 'debug_toolbar.panels.staticfiles.StaticFilesPanel',
    # 'debug_toolbar.panels.templates.TemplatesPanel',
    "debug_toolbar.panels.cache.CachePanel",
    # 'debug_toolbar.panels.signals.SignalsPanel',
    # 'debug_toolbar.panels.logging.LoggingPanel',
    # 'debug_toolbar.panels.redirects.RedirectsPanel',
    # 'debug_toolbar.panels.profiling.ProfilingPanel',
]

# django-extensions
# ------------------------------------------------------------------------------
# INSTALLED_APPS += ('django_extensions', )

INSTALLED_APPS += ("drf_spectacular",)

# Debug toolbar is slow, we disable it for tests
DEBUG_TOOLBAR_ENABLED = env.bool("DEBUG_TOOLBAR_ENABLED", default=DEBUG)
if DEBUG_TOOLBAR_ENABLED:
    MIDDLEWARE += ("debug_toolbar.middleware.DebugToolbarMiddleware",)
    INSTALLED_APPS += ("debug_toolbar",)

# TESTING
# ------------------------------------------------------------------------------
TEST_RUNNER = "django.test.runner.DiscoverRunner"

# CELERY
CELERY_TASK_ALWAYS_EAGER = False
# END CELERY

# Your local stuff: Below this line define 3rd party library settings

CSRF_TRUSTED_ORIGINS = [o for o in ALLOWED_HOSTS]

REST_FRAMEWORK["DEFAULT_SCHEMA_CLASS"] = "drf_spectacular.openapi.AutoSchema"
SPECTACULAR_SETTINGS = {
    "TITLE": "Funkwhale API",
    "DESCRIPTION": open("Readme.md", "r").read(),
    "VERSION": funkwhale_version,
    "SCHEMA_PATH_PREFIX": "/api/(v[0-9])?",
    "OAUTH_FLOWS": ["authorizationCode"],
    "AUTHENTICATION_WHITELIST": [
        "funkwhale_api.common.authentication.OAuth2Authentication",
        "funkwhale_api.common.authentication.ApplicationTokenAuthentication",
    ],
    "SERVERS": [
        {"url": "https://demo.funkwhale.audio", "description": "Demo Server"},
        {
            "url": "https://funkwhale.audio",
            "description": "Read server with real content",
        },
        {
            "url": "https://{domain}",
            "description": "Custom server",
            "variables": {
                "domain": {
                    "default": "yourdomain",
                    "description": "Your Funkwhale Domain",
                },
                "protocol": {"enum": ["http", "https"], "default": "https"},
            },
        },
    ],
    "OAUTH2_FLOWS": ["authorizationCode"],
    "OAUTH2_AUTHORIZATION_URL": "/authorize",
    "OAUTH2_TOKEN_URL": "/api/v1/oauth/token/",
}

if env.bool("WEAK_PASSWORDS", default=False):
    # Faster during tests
    PASSWORD_HASHERS = ("django.contrib.auth.hashers.MD5PasswordHasher",)

MIDDLEWARE = (
    "funkwhale_api.common.middleware.DevHttpsMiddleware",
    "funkwhale_api.common.middleware.ProfilerMiddleware",
    "funkwhale_api.common.middleware.PymallocMiddleware",
) + MIDDLEWARE


class CustomOAuthExt(OpenApiAuthenticationExtension):
    target_class = "funkwhale_api.common.authentication.OAuth2Authentication"
    name = "oauth2"

    def get_security_definition(self, auto_schema):
        from oauth2_provider.scopes import get_scopes_backend

        from drf_spectacular.settings import spectacular_settings

        flows = {}
        for flow_type in spectacular_settings.OAUTH2_FLOWS:
            flows[flow_type] = {}
            if flow_type in ("implicit", "authorizationCode"):
                flows[flow_type][
                    "authorizationUrl"
                ] = spectacular_settings.OAUTH2_AUTHORIZATION_URL
            if flow_type in ("password", "clientCredentials", "authorizationCode"):
                flows[flow_type]["tokenUrl"] = spectacular_settings.OAUTH2_TOKEN_URL
            if spectacular_settings.OAUTH2_REFRESH_URL:
                flows[flow_type]["refreshUrl"] = spectacular_settings.OAUTH2_REFRESH_URL
            scope_backend = get_scopes_backend()
            flows[flow_type]["scopes"] = scope_backend.get_all_scopes()

        return {"type": "oauth2", "flows": flows}
