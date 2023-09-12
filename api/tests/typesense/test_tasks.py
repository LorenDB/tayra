import logging

import requests_mock
import typesense

from funkwhale_api.typesense import tasks


def test_add_tracks_to_index_fails(mocker, caplog):
    logger = logging.getLogger("funkwhale_api.typesense.tasks")
    caplog.set_level(logging.INFO)
    logger.addHandler(caplog.handler)

    client = typesense.Client(
        {
            "api_key": "api_key",
            "nodes": [{"host": "host", "port": "port", "protocol": "protocol"}],
            "connection_timeout_seconds": 2,
        }
    )

    with requests_mock.Mocker() as r_mocker:
        r_mocker.post(
            "protocol://host:port/collections/canonical_fw_data/documents/import",
            json=[{"name": "data"}],
        )
        mocker.patch.object(typesense, "Client", return_value=client)
        mocker.patch.object(
            typesense.client.ApiCall,
            "post",
            side_effect=typesense.exceptions.TypesenseClientError("Hello"),
        )
        tasks.add_tracks_to_index([1, 2, 3])
        assert "Can't build index" in caplog.text


def test_build_canonical_index_success(mocker, caplog, factories):
    logger = logging.getLogger("funkwhale_api.typesense.tasks")
    caplog.set_level(logging.INFO)
    logger.addHandler(caplog.handler)

    client = typesense.Client(
        {
            "api_key": "api_key",
            "nodes": [{"host": "host", "port": "port", "protocol": "protocol"}],
            "connection_timeout_seconds": 2,
        }
    )

    factories["music.Track"].create_batch(size=5)

    with requests_mock.Mocker() as r_mocker:
        mocker.patch.object(typesense, "Client", return_value=client)

        r_mocker.post("protocol://host:port/collections", json={"name": "data"})

        tasks.build_canonical_index()
        assert "Launching async task to add " in caplog.text
