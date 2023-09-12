import pytest
import troi.core
from django.core.cache import cache
from django.db.models import Q
from requests.exceptions import ConnectTimeout

from funkwhale_api.music.models import Track
from funkwhale_api.radios import lb_recommendations
from funkwhale_api.typesense import factories as custom_factories
from funkwhale_api.typesense import utils


def test_can_build_radio_queryset_with_fw_db(factories, mocker):
    factories["music.Track"](
        title="I Want It That Way", mbid="87dfa566-21c3-45ed-bc42-1d345b8563fa"
    )
    factories["music.Track"](
        title="The Perfect Kiss", mbid="ec0da94e-fbfe-4eb0-968e-024d4c32d1d0"
    )
    factories["music.Track"]()

    qs = Track.objects.all()

    mocker.patch("funkwhale_api.typesense.utils.resolve_recordings_to_fw_track")

    radio_qs = lb_recommendations.build_radio_queryset(
        custom_factories.DummyPatch(), {"min_recordings": 1}, qs
    )
    recommended_recording_mbids = [
        "87dfa566-21c3-45ed-bc42-1d345b8563fa",
        "ec0da94e-fbfe-4eb0-968e-024d4c32d1d0",
    ]

    assert list(
        Track.objects.all().filter(Q(mbid__in=recommended_recording_mbids))
    ) == list(radio_qs)


def test_build_radio_queryset_without_fw_db(mocker):
    resolve_recordings_to_fw_track = mocker.patch.object(
        utils, "resolve_recordings_to_fw_track", return_value=None
    )
    # mocker.patch.object(cache, "get_many", return_value=None)

    qs = Track.objects.all()

    with pytest.raises(ValueError):
        lb_recommendations.build_radio_queryset(
            custom_factories.DummyPatch(), {"min_recordings": 1}, qs
        )

        assert resolve_recordings_to_fw_track.called_once_with(
            custom_factories.recommended_recording_mbids
        )


def test_build_radio_queryset_with_redis_and_fw_db(factories, mocker):
    factories["music.Track"](
        pk="1", title="I Want It That Way", mbid="87dfa566-21c3-45ed-bc42-1d345b8563fa"
    )
    mocker.patch.object(utils, "resolve_recordings_to_fw_track", return_value=None)
    redis_cache = {}
    redis_cache["ec0da94e-fbfe-4eb0-968e-024d4c32d1d0"] = 2
    mocker.patch.object(cache, "get_many", return_value=redis_cache)

    qs = Track.objects.all()

    assert list(
        lb_recommendations.build_radio_queryset(
            custom_factories.DummyPatch(), {"min_recordings": 1}, qs
        )
    ) == list(Track.objects.all().filter(pk__in=[1, 2]))


def test_build_radio_queryset_with_redis_and_without_fw_db(factories, mocker):
    factories["music.Track"](
        pk="1", title="Super title", mbid="87dfaaaa-2aaa-45ed-bc42-1d34aaaaaaaa"
    )
    mocker.patch.object(utils, "resolve_recordings_to_fw_track", return_value=None)
    redis_cache = {}
    redis_cache["87dfa566-21c3-45ed-bc42-1d345b8563fa"] = 1
    mocker.patch.object(cache, "get_many", return_value=redis_cache)
    qs = Track.objects.all()

    assert list(
        lb_recommendations.build_radio_queryset(
            custom_factories.DummyPatch(), {"min_recordings": 1}, qs
        )
    ) == list(Track.objects.all().filter(pk=1))


def test_build_radio_queryset_catch_troi_ConnectTimeout(mocker):
    mocker.patch.object(
        troi.core,
        "generate_playlist",
        side_effect=ConnectTimeout,
    )
    qs = Track.objects.all()

    with pytest.raises(ValueError):
        lb_recommendations.build_radio_queryset(
            custom_factories.DummyPatch(), {"min_recordings": 1}, qs
        )


def test_build_radio_queryset_catch_troi_no_candidates(mocker):
    mocker.patch.object(
        troi.core,
        "generate_playlist",
    )
    qs = Track.objects.all()

    with pytest.raises(ValueError):
        lb_recommendations.build_radio_queryset(
            custom_factories.DummyPatch(), {"min_recordings": 1}, qs
        )
