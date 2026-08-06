from django.conf.urls import include, url

from funkwhale_api.common import routers

from . import views

library_router = routers.OptionalSlashRouter()
library_router.register(r"albums", views.ManageAlbumViewSet, "albums")
library_router.register(r"artists", views.ManageArtistViewSet, "artists")
library_router.register(r"libraries", views.ManageLibraryViewSet, "libraries")
library_router.register(r"tracks", views.ManageTrackViewSet, "tracks")
library_router.register(r"uploads", views.ManageUploadViewSet, "uploads")

users_router = routers.OptionalSlashRouter()
users_router.register(r"users", views.ManageUserViewSet, "users")
users_router.register(r"invitations", views.ManageInvitationViewSet, "invitations")

other_router = routers.OptionalSlashRouter()
other_router.register(r"channels", views.ManageChannelViewSet, "channels")
other_router.register(r"tags", views.ManageTagViewSet, "tags")

urlpatterns = [
    url(r"^library/", include((library_router.urls, "instance"), namespace="library")),
    url(r"^users/", include((users_router.urls, "instance"), namespace="users")),
] + other_router.urls
