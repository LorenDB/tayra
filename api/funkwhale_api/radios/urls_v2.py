from funkwhale_api.common import routers

from . import views

router = routers.OptionalSlashRouter()

router.register(r"sessions", views.V2_RadioSessionViewSet, "sessions")


urlpatterns = router.urls
