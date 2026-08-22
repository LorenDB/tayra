import pytest

from funkwhale_api.music import factories

pytestmark = pytest.mark.django_db


def test_admin_list_libraries_scope_me_returns_only_own(factories, superuser_api_client):
    admin = superuser_api_client.user
    own_library = factories["music.Library"](owner=admin, privacy_level="me")
    factories["music.Library"](privacy_level="everyone")
    factories["music.Library"](privacy_level="instance")

    url = "/api/v1/libraries/"
    response = superuser_api_client.get(url, {"scope": "me"})

    assert response.status_code == 200
    assert response.data["count"] == 1
    assert response.data["results"][0]["uuid"] == str(own_library.uuid)


def test_library_moderator_list_libraries_scope_me_returns_only_own(
    factories, api_client
):
    moderator = factories["users.User"](permission_library=True)
    api_client.force_authenticate(user=moderator)
    own_library = factories["music.Library"](owner=moderator, privacy_level="instance")
    factories["music.Library"](privacy_level="everyone")
    factories["music.Library"](privacy_level="instance")

    url = "/api/v1/libraries/"
    response = api_client.get(url, {"scope": "me"})

    assert response.status_code == 200
    assert response.data["count"] == 1
    assert response.data["results"][0]["uuid"] == str(own_library.uuid)


def test_user_list_libraries_scope_me_returns_only_own(factories, logged_in_api_client):
    user = logged_in_api_client.user
    own_library = factories["music.Library"](owner=user, privacy_level="everyone")
    factories["music.Library"](privacy_level="everyone")
    factories["music.Library"](privacy_level="instance")

    url = "/api/v1/libraries/"
    response = logged_in_api_client.get(url, {"scope": "me"})

    assert response.status_code == 200
    assert response.data["count"] == 1
    assert response.data["results"][0]["uuid"] == str(own_library.uuid)
