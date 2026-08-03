"""
Production Configurations

- Use djangosecure
- Use Amazon's S3 for storing static files and uploaded media
- Use mailgun to send e-mails
- Use Redis on Heroku


"""

from django.core.exceptions import ImproperlyConfigured

from .common import *  # noqa

# SECRET CONFIGURATION
# ------------------------------------------------------------------------------
# See: https://docs.djangoproject.com/en/dev/ref/settings/#secret-key
# Raises ImproperlyConfigured exception if DJANGO_SECRET_KEY not in os.environ
SECRET_KEY = env("DJANGO_SECRET_KEY")

# M13: reject placeholder / trivially weak secrets in production.
_WEAK_SECRET_MARKERS = (
    "change-me",
    "changeme",
    "insecure",
    "secret-key",
    "django-insecure",
    "your-secret",
    "placeholder",
)
_secret_lower = (SECRET_KEY or "").strip().lower()
if (
    not SECRET_KEY
    or len(SECRET_KEY) < 40
    or any(marker in _secret_lower for marker in _WEAK_SECRET_MARKERS)
):
    raise ImproperlyConfigured(
        "DJANGO_SECRET_KEY is missing, too short (<40 chars), or still a "
        "placeholder (e.g. 'change-me-…'). Generate a strong random value, e.g.:\n"
        "  python -c \"import secrets; print(secrets.token_urlsafe(50))\""
    )

# django-secure
# ------------------------------------------------------------------------------
# INSTALLED_APPS += ("djangosecure", )
#
# SECURITY_MIDDLEWARE = (
#     'djangosecure.middleware.SecurityMiddleware',
# )
#
#
# # Make sure djangosecure.middleware.SecurityMiddleware is listed first
# MIDDLEWARE = SECURITY_MIDDLEWARE + MIDDLEWARE
#
# # set this to 60 seconds and then to 518400 when you can prove it works
# SECURE_HSTS_SECONDS = 60
# SECURE_HSTS_INCLUDE_SUBDOMAINS = env.bool(
#     "DJANGO_SECURE_HSTS_INCLUDE_SUBDOMAINS", default=True)
# SECURE_FRAME_DENY = env.bool("DJANGO_SECURE_FRAME_DENY", default=True)
# SECURE_CONTENT_TYPE_NOSNIFF = env.bool(
#     "DJANGO_SECURE_CONTENT_TYPE_NOSNIFF", default=True)
# SECURE_BROWSER_XSS_FILTER = True
# Prefer Secure cookies when the pod is served over HTTPS. Default follows
# FUNKWHALE_PROTOCOL so HTTPS deployments get secure cookies without an extra
# env flag; HTTP-only pods can set SESSION_COOKIE_SECURE=false explicitly.
_secure_cookie_default = FUNKWHALE_PROTOCOL == "https"
SESSION_COOKIE_SECURE = env.bool(
    "SESSION_COOKIE_SECURE", default=_secure_cookie_default
)
CSRF_COOKIE_SECURE = env.bool("CSRF_COOKIE_SECURE", default=SESSION_COOKIE_SECURE)
SESSION_COOKIE_HTTPONLY = True
# SECURE_SSL_REDIRECT = env.bool("DJANGO_SECURE_SSL_REDIRECT", default=True)

# SITE CONFIGURATION
# ------------------------------------------------------------------------------
# Hosts/domain names that are valid for this site
# See https://docs.djangoproject.com/en/1.6/ref/settings/#allowed-hosts
# Keep common.py's CORS-aligned CSRF list and ensure ALLOWED_HOSTS is present.
CSRF_TRUSTED_ORIGINS = list(
    dict.fromkeys(list(CSRF_TRUSTED_ORIGINS) + list(ALLOWED_HOSTS))
)

# END SITE CONFIGURATION

# Static Assets
# ------------------------
STATICFILES_STORAGE = "django.contrib.staticfiles.storage.StaticFilesStorage"

# TEMPLATE CONFIGURATION
# ------------------------------------------------------------------------------
# See:
# https://docs.djangoproject.com/en/dev/ref/templates/api/#django.template.loaders.cached.Loader
TEMPLATES[0]["OPTIONS"]["loaders"] = [
    (
        "django.template.loaders.cached.Loader",
        [
            "django.template.loaders.filesystem.Loader",
            "django.template.loaders.app_directories.Loader",
        ],
    )
]

# CACHING
# ------------------------------------------------------------------------------
# Heroku URL does not pass the DB number, so we parse it in

# Your production stuff: Below this line define 3rd party library settings
