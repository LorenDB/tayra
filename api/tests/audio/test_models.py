import pytest
from django.urls import reverse

from funkwhale_api.common import utils as common_utils


def test_channel(factories, now):
    channel = factories["audio.Channel"]()
    assert channel.artist is not None
    assert channel.owner is not None
    assert channel.preferred_username is not None
    assert channel.library is not None
    assert channel.is_local is True
    assert channel.creation_date >= now


def test_channel_get_rss_url_local(factories):
    channel = factories["audio.Channel"](local=True)
    expected = common_utils.full_url(
        reverse(
            "api:v1:channels-rss",
            kwargs={"composite": channel.preferred_username},
        )
    )
    assert channel.get_rss_url() == expected


def test_channel_get_rss_url_external(factories):
    channel = factories["audio.Channel"](external=True)
    assert channel.get_rss_url() == channel.rss_url


def test_channel_delete(factories):
    channel = factories["audio.Channel"]()
    library = channel.library
    artist = channel.artist
    channel.delete()

    for obj in [library, artist]:
        with pytest.raises(obj.DoesNotExist):
            obj.refresh_from_db()
