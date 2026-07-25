from django.conf.urls import url

from funkwhale_api.common import routers

from . import views

router = routers.OptionalSlashRouter()
router.register(r"client-devices", views.ClientDeviceViewSet, "client-devices")
router.register(r"playback-progress", views.PlaybackProgressViewSet, "playback-progress")

# GET/PUT on collection only (not a standard router list/detail pair).
client_preferences = views.ClientPreferenceViewSet.as_view(
    {"get": "list", "put": "update"}
)

urlpatterns = router.urls + [
    url(
        r"^client-preferences/?$",
        client_preferences,
        name="client-preferences-list",
    ),
]
