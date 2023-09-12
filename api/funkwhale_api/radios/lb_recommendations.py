import logging
import time

import troi
import troi.core
from django.core.cache import cache
from django.core.exceptions import ValidationError
from django.db.models import Q
from requests.exceptions import ConnectTimeout

from funkwhale_api.music import models as music_models
from funkwhale_api.typesense import utils

logger = logging.getLogger(__name__)


patches = troi.utils.discover_patches()

SUPPORTED_PATCHES = patches.keys()


def run(config, **kwargs):
    """Validate the received config and run the queryset generation"""
    candidates = kwargs.pop("candidates", music_models.Track.objects.all())
    validate(config)
    return TroiPatch().get_queryset(config, candidates)


def validate(config):
    patch = config.get("patch")
    if patch not in SUPPORTED_PATCHES:
        raise ValidationError(
            'Invalid patch "{}". Supported patches: {}'.format(
                config["patch"], SUPPORTED_PATCHES
            )
        )

    return True


def build_radio_queryset(patch, config, radio_qs):
    """Take a troi patch and its arg, match the missing mbid and then build a radio queryset"""

    logger.info("Config used for troi radio generation is " + str(config))

    start_time = time.time()
    try:
        recommendations = troi.core.generate_playlist(patch, config)
    except ConnectTimeout:
        raise ValueError(
            "Timed out while connecting to ListenBrainz. No candidates could be retrieved for the radio."
        )
    end_time_rec = time.time()
    logger.info("Troi fetch took :" + str(end_time_rec - start_time))

    if not recommendations:
        raise ValueError("No candidates found by troi")

    recommended_recording_mbids = [
        recommended_recording.mbid
        for recommended_recording in recommendations.playlists[0].recordings
    ]

    logger.info("Searching for MusicBrainz ID in Funkwhale database")

    qs_mbid = music_models.Track.objects.all().filter(
        mbid__in=recommended_recording_mbids
    )
    mbids_found = [str(i.mbid) for i in qs_mbid]

    recommended_recording_mbids_not_found = [
        mbid for mbid in recommended_recording_mbids if mbid not in mbids_found
    ]
    cached_mbid_match = cache.get_many(recommended_recording_mbids_not_found)

    if qs_mbid and cached_mbid_match:
        logger.info("MusicBrainz IDs found in Funkwhale database and redis")
        mbids_found = [str(i.mbid) for i in qs_mbid]
        mbids_found.extend([i for i in cached_mbid_match.keys()])
    elif qs_mbid and not cached_mbid_match:
        logger.info("MusicBrainz IDs found in Funkwhale database")
        mbids_found = mbids_found
    elif not qs_mbid and cached_mbid_match:
        logger.info("MusicBrainz IDs found in redis cache")
        mbids_found = [i for i in cached_mbid_match.keys()]
    else:
        logger.info(
            "Couldn't find any matches in Funkwhale database. Trying to match all"
        )
        mbids_found = []

    recommended_recordings_not_found = [
        i for i in recommendations.playlists[0].recordings if i.mbid not in mbids_found
    ]

    logger.info("Matching missing MusicBrainz ID to Funkwhale track")

    start_time_resolv = time.time()
    utils.resolve_recordings_to_fw_track(recommended_recordings_not_found)
    end_time_resolv = time.time()

    logger.info(
        "Resolving "
        + str(len(recommended_recordings_not_found))
        + " tracks in "
        + str(end_time_resolv - start_time_resolv)
    )

    cached_mbid_match = cache.get_many(recommended_recording_mbids_not_found)

    if not qs_mbid and not cached_mbid_match:
        raise ValueError("No candidates found for troi radio")

    logger.info("Radio generation with troi took " + str(end_time_resolv - start_time))
    logger.info("qs_mbid is " + str(mbids_found))

    if qs_mbid and cached_mbid_match:
        return radio_qs.filter(
            Q(mbid__in=mbids_found) | Q(pk__in=cached_mbid_match.values())
        )
    if qs_mbid and not cached_mbid_match:
        return radio_qs.filter(mbid__in=mbids_found)

    if not qs_mbid and cached_mbid_match:
        return radio_qs.filter(pk__in=cached_mbid_match.values())


class TroiPatch:
    code = "troi-patch"
    label = "Troi Patch"

    def get_queryset(self, config, qs):
        patch_string = config.pop("patch")
        patch = patches[patch_string]
        return build_radio_queryset(patch(), config, qs)
