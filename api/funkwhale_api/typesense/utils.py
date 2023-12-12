import logging
import re

import unidecode
from django.conf import settings
from django.core.cache import cache
from lb_matching_tools.cleaner import MetadataCleaner

from funkwhale_api.music import models as music_models

logger = logging.getLogger(__name__)

api_key = settings.TYPESENSE_API_KEY
host = settings.TYPESENSE_HOST
port = settings.TYPESENSE_PORT
protocol = settings.TYPESENSE_PROTOCOL
TYPESENSE_NUM_TYPO = settings.TYPESENSE_NUM_TYPO


class TypesenseNotActivate(Exception):
    pass


if not settings.TYPESENSE_API_KEY:
    logger.info(
        "Typesense is not activated. You can enable it by setting the TYPESENSE_API_KEY env variable."
    )
else:
    import typesense


def delete_non_alnum_characters(text):
    return unidecode.unidecode(re.sub(r"[^\w]+", "", text).lower())


def resolve_recordings_to_fw_track(recordings):
    """
    Tries to match a troi recording entity to a fw track using the typesense index.
    It will save the results in the match_mbid attribute of the Track table.
    For test purposes : if multiple fw tracks are returned, we log the information
    but only keep the best result in db to avoid duplicates.
    """

    if not settings.TYPESENSE_API_KEY:
        raise TypesenseNotActivate(
            "Typesense is not activated. You can enable it by setting the TYPESENSE_API_KEY env variable."
        )

    client = typesense.Client(
        {
            "api_key": api_key,
            "nodes": [{"host": host, "port": port, "protocol": protocol}],
            "connection_timeout_seconds": 2,
        }
    )

    mc = MetadataCleaner()

    for recording in recordings:
        rec = mc.clean_recording(recording.name)
        artist = mc.clean_artist(recording.artist.name)
        canonical_name_for_track = delete_non_alnum_characters(artist + rec)

        logger.debug(f"Trying to resolve : {canonical_name_for_track}")

        search_parameters = {
            "q": canonical_name_for_track,
            "query_by": "combined",
            "num_typos": TYPESENSE_NUM_TYPO,
            "drop_tokens_threshold": 0,
        }
        matches = client.collections["canonical_fw_data"].documents.search(
            search_parameters
        )

        if matches["hits"]:
            hit = matches["hits"][0]
            pk = hit["document"]["pk"]
            logger.debug(f"Saving match for track with primary key {pk}")
            cache.set(recording.mbid, pk)

            if settings.DEBUG and matches["hits"][1]:
                for hit in matches["hits"][1:]:
                    pk = hit["document"]["pk"]
                    fw_track = music_models.Track.objects.get(pk=pk)
                    logger.info(
                        f"Duplicate match found for {fw_track.artist.name} {fw_track.title} \
                                and primary key {pk}. Skipping because of better match."
                    )
        else:
            logger.debug("No match found in fw db")
    return cache.get_many([rec.mbid for rec in recordings])
