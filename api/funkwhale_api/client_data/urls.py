from funkwhale_api.common import routers

from . import views

router = routers.OptionalSlashRouter()
router.register(r"client-devices", views.ClientDeviceViewSet, "client-devices")

urlpatterns = router.urls
