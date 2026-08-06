import pytest
from django.urls import reverse

from funkwhale_api.audio import categories, models, renderers, serializers, views
from funkwhale_api.common import locales, utils


def test_channel_create(logged_in_api_client):
    user = logged_in_api_client.user

    data = {
        # TODO: cover
        "name": "My channel",
        "username": "mychannel",
        "description": {"text": "This is my channel", "content_type": "text/markdown"},
        "tags": ["hello", "world"],
        "content_category": "podcast",
        "metadata": {"language": "en", "itunes_category": "Sports"},
    }

    url = reverse("api:v1:channels-list")
    response = logged_in_api_client.post(url, data, format="json")

    assert response.status_code == 201

    channel = views.ChannelViewSet.queryset.get(owner=user)
    expected = serializers.ChannelSerializer(
        channel, context={"subscriptions_count": True}
    ).data

    assert response.data == expected
    assert channel.artist.name == data["name"]
    assert (
        sorted(channel.artist.tagged_items.values_list("tag__name", flat=True))
        == data["tags"]
    )
    assert channel.owner == user
    assert channel.artist.description.text == data["description"]["text"]
    assert (
        channel.artist.description.content_type == data["description"]["content_type"]
    )
    assert channel.preferred_username == data["username"]
    assert channel.library.privacy_level == "everyone"
    assert channel.library.owner == user


@pytest.mark.parametrize(
    "field",
    ["uuid", "preferred_username"],
)
def test_channel_detail(field, factories, logged_in_api_client):
    channel = factories["audio.Channel"](
        artist__description=None, local=True, artist__with_cover=True
    )

    url = reverse(
        "api:v1:channels-detail",
        kwargs={"composite": utils.recursive_getattr(channel, field)},
    )
    setattr(channel.artist, "_tracks_count", 0)
    setattr(channel.artist, "_prefetched_tagged_items", [])

    expected = serializers.ChannelSerializer(
        channel, context={"subscriptions_count": True}
    ).data
    response = logged_in_api_client.get(url)

    assert response.status_code == 200
    assert response.data == expected


def test_channel_list(factories, logged_in_api_client):
    channel = factories["audio.Channel"](
        artist__description=None, artist__with_cover=True
    )
    setattr(channel.artist, "_tracks_count", 0)
    setattr(channel.artist, "_prefetched_tagged_items", [])
    url = reverse("api:v1:channels-list")
    expected = serializers.ChannelSerializer(channel).data
    response = logged_in_api_client.get(url)

    assert response.status_code == 200
    assert response.data == {
        "results": [expected],
        "count": 1,
        "next": None,
        "previous": None,
    }


def test_channel_list_opml(factories, logged_in_api_client, now):
    channel1 = factories["audio.Channel"]()
    channel2 = factories["audio.Channel"]()
    expected_xml = serializers.get_opml(
        channels=[channel2, channel1], title="Funkwhale channels OPML export", date=now
    )
    expected_content = renderers.render_xml(
        renderers.dict_to_xml_tree("opml", expected_xml)
    )
    url = reverse("api:v1:channels-list")
    response = logged_in_api_client.get(url, {"output": "opml"})

    assert response.status_code == 200
    assert response.content == expected_content
    assert response["content-type"] == "application/xml"


def test_channel_update(logged_in_api_client, factories):
    user = logged_in_api_client.user
    channel = factories["audio.Channel"](owner=user)

    data = {
        # TODO: cover
        "name": "new name"
    }

    url = reverse("api:v1:channels-detail", kwargs={"composite": channel.uuid})
    response = logged_in_api_client.patch(url, data)

    assert response.status_code == 200

    channel.refresh_from_db()

    assert channel.artist.name == data["name"]


def test_channel_update_permission(logged_in_api_client, factories):
    channel = factories["audio.Channel"]()

    data = {"name": "new name"}

    url = reverse("api:v1:channels-detail", kwargs={"composite": channel.uuid})
    response = logged_in_api_client.patch(url, data)

    assert response.status_code == 403


def test_channel_delete(logged_in_api_client, factories):
    user = logged_in_api_client.user
    channel = factories["audio.Channel"](owner=user)

    url = reverse("api:v1:channels-detail", kwargs={"composite": channel.uuid})
    response = logged_in_api_client.delete(url)

    assert response.status_code == 204

    with pytest.raises(channel.DoesNotExist):
        channel.refresh_from_db()


def test_channel_delete_permission(logged_in_api_client, factories):
    channel = factories["audio.Channel"]()

    url = reverse("api:v1:channels-detail", kwargs={"composite": channel.uuid})
    response = logged_in_api_client.patch(url)

    assert response.status_code == 403
    channel.refresh_from_db()


@pytest.mark.parametrize("url_name", ["api:v1:channels-list"])
def test_channel_views_disabled_via_feature_flag(
    url_name, logged_in_api_client, preferences
):
    preferences["audio__channels_enabled"] = False
    url = reverse(url_name)
    response = logged_in_api_client.get(url)
    assert response.status_code == 405


def test_channel_subscribe(factories, logged_in_api_client):
    user = logged_in_api_client.user
    channel = factories["audio.Channel"](artist__description=None)
    url = reverse("api:v1:channels-subscribe", kwargs={"composite": channel.uuid})

    response = logged_in_api_client.post(url)

    assert response.status_code == 201

    subscription = models.ChannelSubscription.objects.get(user=user, channel=channel)
    setattr(subscription.channel.artist, "_tracks_count", 0)
    setattr(subscription.channel.artist, "_prefetched_tagged_items", [])
    expected = serializers.SubscriptionSerializer(subscription).data
    assert response.data == expected


def test_channel_unsubscribe(factories, logged_in_api_client):
    user = logged_in_api_client.user
    channel = factories["audio.Channel"]()
    subscription = factories["audio.Subscription"](channel=channel, user=user)
    url = reverse("api:v1:channels-unsubscribe", kwargs={"composite": channel.uuid})

    response = logged_in_api_client.post(url)

    assert response.status_code == 204

    with pytest.raises(subscription.DoesNotExist):
        subscription.refresh_from_db()


def test_subscriptions_list(factories, logged_in_api_client):
    user = logged_in_api_client.user
    channel = factories["audio.Channel"](
        artist__description=None, artist__with_cover=True
    )
    subscription = factories["audio.Subscription"](channel=channel, user=user)
    setattr(subscription.channel.artist, "_tracks_count", 0)
    setattr(subscription.channel.artist, "_prefetched_tagged_items", [])
    factories["audio.Subscription"](channel=channel)
    url = reverse("api:v1:subscriptions-list")
    expected = serializers.SubscriptionSerializer(subscription).data
    response = logged_in_api_client.get(url)

    assert response.status_code == 200
    assert response.data["results"][0] == expected
    assert response.data == {
        "results": [expected],
        "count": 1,
        "next": None,
        "previous": None,
    }


def test_subscriptions_all(factories, logged_in_api_client):
    user = logged_in_api_client.user
    channel = factories["audio.Channel"](artist__description=None)
    subscription = factories["audio.Subscription"](channel=channel, user=user)
    factories["audio.Subscription"](channel=channel)
    url = reverse("api:v1:subscriptions-all")
    response = logged_in_api_client.get(url)

    assert response.status_code == 200
    assert response.data == {
        "results": [{"uuid": subscription.uuid, "channel": channel.uuid}],
        "count": 1,
    }


def test_channel_rss_feed(factories, api_client, preferences):
    preferences["common__api_authentication_required"] = False
    channel = factories["audio.Channel"](local=True)
    upload1 = factories["music.Upload"](library=channel.library, playable=True)
    upload2 = factories["music.Upload"](library=channel.library, playable=True)

    expected = serializers.rss_serialize_channel_full(
        channel=channel, uploads=[upload2, upload1]
    )

    url = reverse("api:v1:channels-rss", kwargs={"composite": channel.uuid})

    response = api_client.get(url)

    assert response.status_code == 200
    assert response.data == expected
    assert response["Content-Type"] == "application/rss+xml"


def test_channel_rss_feed_redirects_for_external(factories, api_client, preferences):
    preferences["common__api_authentication_required"] = False
    channel = factories["audio.Channel"](external=True)
    factories["music.Upload"](library=channel.library, playable=True)

    url = reverse("api:v1:channels-rss", kwargs={"composite": channel.uuid})

    response = api_client.get(url)

    assert response.status_code == 302
    assert response["Location"] == channel.rss_url


def test_channel_rss_feed_authentication_required(factories, api_client, preferences):
    preferences["common__api_authentication_required"] = True
    channel = factories["audio.Channel"](local=True)

    url = reverse("api:v1:channels-rss", kwargs={"composite": channel.uuid})

    response = api_client.get(url)

    assert response.status_code == 401


def test_channel_metadata_choices(factories, api_client):
    expected = {
        "language": [
            {"value": code, "label": name} for code, name in locales.ISO_639_CHOICES
        ],
        "itunes_category": [
            {"value": code, "label": code, "children": children}
            for code, children in categories.ITUNES_CATEGORIES.items()
        ],
    }

    url = reverse("api:v1:channels-metadata_choices")

    response = api_client.get(url)

    assert response.status_code == 200
    assert response.data == expected


def test_subscribe_to_rss_feed_existing_channel(factories, logged_in_api_client):
    user = logged_in_api_client.user
    rss_url = "http://example.test/rss.url"
    channel = factories["audio.Channel"](rss_url=rss_url, external=True)
    url = reverse("api:v1:channels-rss_subscribe")

    response = logged_in_api_client.post(url, {"url": rss_url})

    assert response.status_code == 201

    subscription = models.ChannelSubscription.objects.get(user=user, channel=channel)

    assert subscription.approved is True

    expected = serializers.SubscriptionSerializer(subscription).data

    assert response.data == expected


def test_subscribe_to_rss_feed_existing_subscription(factories, logged_in_api_client):
    user = logged_in_api_client.user
    rss_url = "http://example.test/rss.url"
    channel = factories["audio.Channel"](rss_url=rss_url, external=True)
    factories["audio.Subscription"](channel=channel, user=user)
    url = reverse("api:v1:channels-rss_subscribe")

    response = logged_in_api_client.post(url, {"url": rss_url})

    assert response.status_code == 201

    assert channel.subscriptions.filter(user=user).count() == 1


def test_subscribe_to_rss_creates_channel(factories, logged_in_api_client, mocker):
    logged_in_api_client.user
    rss_url = "http://example.test/rss.url"
    channel = factories["audio.Channel"]()
    get_channel_from_rss_url = mocker.patch.object(
        serializers, "get_channel_from_rss_url", return_value=(channel, [])
    )
    url = reverse("api:v1:channels-rss_subscribe")

    response = logged_in_api_client.post(url, {"url": rss_url})

    assert response.status_code == 201
    assert response.data["channel"]["uuid"] == channel.uuid

    get_channel_from_rss_url.assert_called_once_with(rss_url)


def test_refresh_channel_when_param_is_true(
    factories,
    mocker,
    logged_in_api_client,
    queryset_equal_queries,
):
    obj = factories["audio.Channel"]()
    refetch_obj = mocker.patch(
        "funkwhale_api.music.views.refetch_obj", return_value=obj
    )
    url = reverse("api:v1:channels-detail", kwargs={"composite": obj.uuid})
    response = logged_in_api_client.get(url, {"refresh": "true"})

    assert response.status_code == 200
    assert refetch_obj.call_count == 1
    assert refetch_obj.call_args[0][0] == obj


def test_can_filter_channels_through_api_scope(factories, logged_in_api_client):
    user = logged_in_api_client.user
    channel = factories["audio.Channel"](owner=user)
    factories["audio.Channel"]()
    url = reverse("api:v1:channels-list")
    response = logged_in_api_client.get(url, {"scope": "me"})

    assert response.status_code == 200
    assert len(response.data["results"]) == 1
    assert response.data["results"][0]["uuid"] == channel.uuid
