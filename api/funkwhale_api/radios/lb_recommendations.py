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

    recommended_mbids = [
        recommended_recording.mbid
        for recommended_recording in recommendations.playlists[0].recordings
    ]

    logger.info("Searching for MusicBrainz ID in Funkwhale database")

    qs_recommended = (
        music_models.Track.objects.all()
        .filter(mbid__in=recommended_mbids)
        .order_by("mbid", "pk")
        .distinct("mbid")
    )
    qs_recommended_mbid = [str(i.mbid) for i in qs_recommended]

    recommended_mbids_not_qs = [
        mbid for mbid in recommended_mbids if mbid not in qs_recommended_mbid
    ]
    cached_match = cache.get_many(recommended_mbids_not_qs)
    cached_match_mbid = [str(i) for i in cached_match.keys()]

    if qs_recommended and cached_match_mbid:
        logger.info("MusicBrainz IDs found in Funkwhale database and redis")
        qs_recommended_mbid.extend(cached_match_mbid)
        mbids_found = qs_recommended_mbid
    elif qs_recommended and not cached_match_mbid:
        logger.info("MusicBrainz IDs found in Funkwhale database")
        mbids_found = qs_recommended_mbid
    elif not qs_recommended and cached_match_mbid:
        logger.info("MusicBrainz IDs found in redis cache")
        mbids_found = cached_match_mbid
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

    cached_match = cache.get_many(recommended_mbids)

    if not mbids_found and not cached_match:
        raise ValueError("No candidates found for troi radio")

    mbids_found_pks = list(
        music_models.Track.objects.all()
        .filter(mbid__in=mbids_found)
        .order_by("mbid", "pk")
        .distinct("mbid")
        .values_list("pk", flat=True)
    )

    mbids_found_pks_unique = [
        i for i in mbids_found_pks if i not in cached_match.keys()
    ]

    if mbids_found and cached_match:
        return radio_qs.filter(
            Q(pk__in=mbids_found_pks_unique) | Q(pk__in=cached_match.values())
        )
    if mbids_found and not cached_match:
        return radio_qs.filter(pk__in=mbids_found_pks_unique)

    if not mbids_found and cached_match:
        return radio_qs.filter(pk__in=cached_match.values())


class TroiPatch:
    code = "troi-patch"
    label = "Troi Patch"

    def get_queryset(self, config, qs):
        patch_string = config.pop("patch")
        patch = patches[patch_string]
        return build_radio_queryset(patch(), config, qs)
