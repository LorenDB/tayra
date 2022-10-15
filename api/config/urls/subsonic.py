from django.conf.urls import include, url
from rest_framework import routers
from rest_framework.urlpatterns import format_suffix_patterns

from funkwhale_api.subsonic.views import SubsonicViewSet

subsonic_router = routers.SimpleRouter(trailing_slash=False)
subsonic_router.register(r"rest", SubsonicViewSet, basename="subsonic")

subsonic_patterns = format_suffix_patterns(subsonic_router.urls, allowed=["view"])
urlpatterns = [url("", include((subsonic_patterns, "subsonic"), namespace="subsonic"))]

# urlpatterns = [
#    url(
#        r"^subsonic/rest/",
#        include((subsonic_router.urls, "subsonic"), namespace="subsonic"),
#    )
# ]
