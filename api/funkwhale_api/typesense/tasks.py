import logging

from django.conf import settings

from funkwhale_api.music import models as music_models
from funkwhale_api.taskapp import celery

from . import utils

logger = logging.getLogger(__name__)


class TypesenseNotActivate(Exception):
    pass


if not settings.TYPESENSE_API_KEY:
    logger.info(
        "Typesense is not activated. You can enable it by setting the TYPESENSE_API_KEY env variable."
    )
else:
    import typesense
    from typesense.exceptions import ObjectAlreadyExists


api_key = settings.TYPESENSE_API_KEY
host = settings.TYPESENSE_HOST
port = settings.TYPESENSE_PORT
protocol = settings.TYPESENSE_PROTOCOL

collection_name = "canonical_fw_data"
BATCH_SIZE = 10000


@celery.app.task(name="typesense.add_tracks_to_index")
def add_tracks_to_index(tracks_pk):
    """
    This will add fw tracks data to the typesense index. It will concatenate the artist name
    and the track title into one string.
    """

    client = typesense.Client(
        {
            "api_key": api_key,
            "nodes": [{"host": host, "port": port, "protocol": protocol}],
            "connection_timeout_seconds": 2,
        }
    )

    try:
        logger.info(f"Updating index {collection_name}")
        tracks = music_models.Track.objects.all().filter(pk__in=tracks_pk)
        documents = []
        for track in tracks:
            document = dict()
            document["pk"] = track.pk
            document["combined"] = utils.delete_non_alnum_characters(
                track.artist.name + track.title
            )
            documents.append(document)

        client.collections[collection_name].documents.import_(
            documents, {"action": "upsert"}
        )

    except typesense.exceptions.TypesenseClientError as err:
        logger.error(f"Can't build index: {str(err)}")


@celery.app.task(name="typesense.build_canonical_index")
def build_canonical_index():
    if not settings.TYPESENSE_API_KEY:
        raise TypesenseNotActivate(
            "Typesense is not activated. You can enable it by setting the TYPESENSE_API_KEY env variable."
        )

    schema = {
        "name": collection_name,
        "fields": [
            {"name": "combined", "type": "string"},
            {"name": "pk", "type": "int32"},
        ],
        "default_sorting_field": "pk",
    }
    client = typesense.Client(
        {
            "api_key": api_key,
            "nodes": [{"host": host, "port": port, "protocol": protocol}],
            "connection_timeout_seconds": 2,
        }
    )
    try:
        client.collections.create(schema)
    except ObjectAlreadyExists:
        pass

    tracks = music_models.Track.objects.all().values_list("pk", flat=True)
    total_tracks = tracks.count()
    total_batches = (total_tracks - 1) // BATCH_SIZE + 1

    for i in range(total_batches):
        start_index = i * BATCH_SIZE
        end_index = (i + 1) * (BATCH_SIZE - 1)
        batch_tracks = tracks[start_index:end_index]
        logger.info(
            f"Launching async task to add {str(batch_tracks)} tracks pks to index"
        )
        add_tracks_to_index.delay(list(batch_tracks))
