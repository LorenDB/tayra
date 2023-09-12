import requests_mock
import typesense
from django.core.cache import cache

from funkwhale_api.typesense import factories as custom_factories
from funkwhale_api.typesense import utils


def test_resolve_recordings_to_fw_track(mocker, factories):
    artist = factories["music.Artist"](name="artist_name")
    factories["music.Track"](
        pk=1,
        title="I Want It That Way",
        artist=artist,
        mbid="87dfa566-21c3-45ed-bc42-1d345b8563fa",
    )
    factories["music.Track"](
        pk=2,
        title="I Want It That Way",
        artist=artist,
    )

    client = typesense.Client(
        {
            "api_key": "api_key",
            "nodes": [{"host": "host", "port": "port", "protocol": "protocol"}],
            "connection_timeout_seconds": 2,
        }
    )
    with requests_mock.Mocker() as r_mocker:
        mocker.patch.object(typesense, "Client", return_value=client)
        mocker.patch.object(
            typesense.client.ApiCall,
            "post",
            return_value=custom_factories.typesense_search_result,
        )
        r_mocker.get(
            "protocol://host:port/collections/canonical_fw_data/documents/search",
            json=custom_factories.typesense_search_result,
        )

        utils.resolve_recordings_to_fw_track(custom_factories.recording_list)
        assert cache.get("87dfa566-21c3-45ed-bc42-1d345b8563fa") == "1"
