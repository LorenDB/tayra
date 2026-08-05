import collections
import logging
import time
import uuid

import requests
from django.contrib.contenttypes.models import ContentType

from funkwhale_api.taskapp import celery

from . import models

logger = logging.getLogger(__name__)

BASE_URL = "https://musicbrainz.org/ws/2/genre/all"
HEADERS = {"Accept": "application/json"}


def get_tags_from_foreign_key(
    ids, foreign_key_model, foreign_key_attr, tagged_items_attr="tagged_items"
):
    """
    Cf #988, this is useful to tag an artist with #Rock if all its tracks are tagged with
    #Rock, for instance.
    """
    data = {}
    objs = foreign_key_model.objects.filter(
        **{f"{foreign_key_attr}__pk__in": ids}
    ).order_by("-id")
    objs = objs.only("id", f"{foreign_key_attr}_id").prefetch_related(tagged_items_attr)

    for obj in objs.iterator():
        # loop on all objects, store the objs tags + counter on the corresponding foreign key
        row_data = data.setdefault(
            getattr(obj, f"{foreign_key_attr}_id"),
            {"total_objs": 0, "tags": []},
        )
        row_data["total_objs"] += 1
        for ti in getattr(obj, tagged_items_attr).all():
            row_data["tags"].append(ti.tag_id)

    # now, keep only tags that are present on all objects, i.e tags where the count
    # matches total_objs
    final_data = {}
    for key, row_data in data.items():
        counter = collections.Counter(row_data["tags"])
        tags_to_keep = sorted(
            [t for t, c in counter.items() if c >= row_data["total_objs"]]
        )
        if tags_to_keep:
            final_data[key] = tags_to_keep
    return final_data


def add_tags_batch(data, model, tagged_items_attr="tagged_items"):
    model_ct = ContentType.objects.get_for_model(model)
    tagged_items = [
        models.TaggedItem(tag_id=tag_id, content_type=model_ct, object_id=obj_id)
        for obj_id, tag_ids in data.items()
        for tag_id in tag_ids
    ]

    return models.TaggedItem.objects.bulk_create(tagged_items, batch_size=2000)


def fetch_musicbrainz_genre():
    """
    Paginate MusicBrainz official genre list (1 request/second).

    Returns a list of dicts with at least ``id`` (MBID string) and ``name``.
    """
    genres = []
    limit = 100
    offset = 0

    while True:
        response = requests.get(
            BASE_URL,
            headers=HEADERS,
            params={"limit": limit, "offset": offset},
            timeout=30,
        )

        if response.status_code == 503 or b"rate limit" in response.content.lower():
            logger.info("MusicBrainz rate limited; sleeping 10s")
            time.sleep(10)
            response = requests.get(
                BASE_URL,
                headers=HEADERS,
                params={"limit": limit, "offset": offset},
                timeout=30,
            )

        if response.status_code != 200:
            logger.warning("Failed to fetch MB genres: %s", response.content[:200])
            break

        data = response.json()
        genres.extend(data.get("genres") or [])

        if offset + limit >= data.get("genre-count", 0):
            break

        offset += limit
        # MusicBrainz allows roughly one request per second for anonymous clients.
        time.sleep(1)

    return genres


@celery.app.task(name="tags.update_musicbrainz_genre")
def update_musicbrainz_genre():
    """
    Seed/update the Tag table with official MusicBrainz genres.

    Existing tags matched by name get an mbid attached; new genres are created.
    """
    existing_mbids = {
        str(m) for m in models.Tag.objects.exclude(mbid=None).values_list("mbid", flat=True)
    }
    genres = fetch_musicbrainz_genre()
    created = 0
    updated = 0
    for genre in genres:
        mbid_raw = genre.get("id")
        name = genre.get("name")
        if not mbid_raw or not name:
            continue
        if mbid_raw in existing_mbids:
            continue
        try:
            mbid = uuid.UUID(str(mbid_raw))
        except (ValueError, TypeError):
            logger.debug("Skipping genre with invalid mbid: %s", mbid_raw)
            continue

        _tag, was_created = models.Tag.objects.update_or_create(
            name=name,
            defaults={"mbid": mbid},
        )
        if was_created:
            created += 1
        else:
            updated += 1
        existing_mbids.add(str(mbid))

    logger.info(
        "MusicBrainz genre sync finished: %s created, %s updated, %s total from MB",
        created,
        updated,
        len(genres),
    )
    return {"created": created, "updated": updated, "fetched": len(genres)}
