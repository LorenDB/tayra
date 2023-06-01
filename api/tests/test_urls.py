from django.urls import reverse


def test_can_resolve_v1():
    path = reverse("api:v1:instance:nodeinfo-2.0")
    assert path == "/api/v1/instance/nodeinfo/2.0"


def test_can_resolve_subsonic():
    path = reverse("api:subsonic:subsonic-ping")
    assert path == "/api/subsonic/rest/ping"


def test_can_resolve_v2():
    path = reverse("api:v2:instance:nodeinfo-2.0")
    assert path == "/api/v2/instance/nodeinfo/2.0"
