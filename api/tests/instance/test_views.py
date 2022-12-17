from unittest import mock

from django.urls import reverse


def test_nodeinfo_endpoint(db, api_client):
    url = reverse("api:v1:instance:nodeinfo-2.0")
    response = api_client.get(url)
    ct = "application/json; profile=http://nodeinfo.diaspora.software/ns/schema/2.0#; charset=utf-8"  # noqa
    assert response.status_code == 200
    assert response["Content-Type"] == ct


def test_settings_only_list_public_settings(db, api_client, preferences):
    url = reverse("api:v1:instance:settings")
    response = api_client.get(url)

    for conf in response.data:
        p = preferences.model.objects.get(section=conf["section"], name=conf["name"])
        assert p.preference.show_in_api is True


def test_admin_settings_restrict_access(db, logged_in_api_client, preferences):
    url = reverse("api:v1:instance:admin-settings-list")
    response = logged_in_api_client.get(url)

    assert response.status_code == 403


def test_admin_settings_correct_permission(db, logged_in_api_client, preferences):
    user = logged_in_api_client.user
    user.permission_settings = True
    user.save()
    url = reverse("api:v1:instance:admin-settings-list")
    response = logged_in_api_client.get(url)

    assert response.status_code == 200
    assert len(response.data) == len(preferences.all())


def test_manifest_endpoint(api_client, preferences):
    with mock.patch(
        "funkwhale_api.instance.views.PWA_MANIFEST",
        {"lang": "unchanged"},
    ):
        preferences["instance__name"] = "Test pod"
        preferences["instance__short_description"] = "Test description"
        expected = {
            "lang": "unchanged",
            "name": "Test pod",
            "short_name": "Test pod",
            "description": "Test description",
        }

        url = reverse("api:v1:instance:spa-manifest")
        response = api_client.get(url)
        assert response.status_code == 200
        assert response.data == expected
