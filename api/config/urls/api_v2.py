from django.conf.urls import include, url

from funkwhale_api.common import routers as common_routers

router = common_routers.OptionalSlashRouter()
v2_patterns = router.urls

v2_patterns += [
    url(
        r"^instance/",
        include(("funkwhale_api.instance.urls_v2", "instance"), namespace="instance"),
    ),
    url(
        r"^radios/",
        include(("funkwhale_api.radios.urls_v2", "radios"), namespace="radios"),
    ),
]

urlpatterns = [url("", include((v2_patterns, "v2"), namespace="v2"))]
