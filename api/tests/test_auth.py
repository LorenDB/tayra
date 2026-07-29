from django.urls import reverse


def test_can_authenticate_using_oauth_token_param_in_url(
    factories, preferences, client, mocker
):
    mocker.patch(
        "funkwhale_api.users.oauth.permissions.should_allow", return_value=True
    )
    token = factories["users.AccessToken"]()
    preferences["common__api_authentication_required"] = True
    url = reverse("api:v1:tracks-list")
    response = client.get(url)

    assert response.status_code == 401

    response = client.get(url, data={"token": token.token})
    assert response.status_code == 200
