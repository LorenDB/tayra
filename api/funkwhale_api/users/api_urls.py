from django.conf.urls import url

from funkwhale_api.common import routers

from . import views
from .oidc import views as oidc_views

router = routers.OptionalSlashRouter()
router.register(r"users", views.UserViewSet, "users")

urlpatterns = [
    url(r"^users/login/?$", views.login, name="login"),
    url(r"^users/logout/?$", views.logout, name="logout"),
    # First-party Tayra password → OAuth tokens
    url(
        r"^users/token/challenge/?$",
        views.token_login_challenge,
        name="token_login_challenge",
    ),
    url(r"^users/token/?$", views.token_login, name="token_login"),
    # Complete password login after TOTP challenge
    url(r"^users/token/2fa/?$", views.token_login_2fa, name="token_login_2fa"),
    # OIDC SSO
    url(r"^users/auth-methods/?$", oidc_views.auth_methods, name="auth_methods"),
    url(r"^users/oidc/login/?$", oidc_views.oidc_login, name="oidc_login"),
    url(r"^users/oidc/callback/?$", oidc_views.oidc_callback, name="oidc_callback"),
    url(r"^users/oidc/token/?$", oidc_views.oidc_token, name="oidc_token"),
] + router.urls
