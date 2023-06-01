from django.conf.urls import include, url

from funkwhale_api.common import routers as common_routers

router = common_routers.OptionalSlashRouter()
v2_patterns = router.urls

v2_patterns += [
    url(
        r"^instance/",
        include(("funkwhale_api.instance.urls", "instance"), namespace="instance"),
    ),
]

urlpatterns = [url("", include((v2_patterns, "v2"), namespace="v2"))]
