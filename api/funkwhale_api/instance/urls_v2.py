from django.conf.urls import url

from . import views

urlpatterns = [
    url(r"^nodeinfo/2.1/?$", views.NodeInfo21.as_view(), name="nodeinfo-2.1"),
]
