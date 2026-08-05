import uuid

from funkwhale_api.tags import models, tasks


def test_update_musicbrainz_genre_creates_tags(factories, mocker):
    mbid1 = str(uuid.uuid4())
    mbid2 = str(uuid.uuid4())
    mocker.patch(
        "funkwhale_api.tags.tasks.fetch_musicbrainz_genre",
        return_value=[
            {"id": mbid1, "name": "rock"},
            {"id": mbid2, "name": "jazz"},
        ],
    )

    result = tasks.update_musicbrainz_genre()

    assert result["created"] == 2
    assert result["fetched"] == 2
    assert models.Tag.objects.filter(name="rock", mbid=mbid1).exists()
    assert models.Tag.objects.filter(name="jazz", mbid=mbid2).exists()


def test_update_musicbrainz_genre_idempotent(factories, mocker):
    mbid = str(uuid.uuid4())
    models.Tag.objects.create(name="ambient", mbid=mbid)
    mocker.patch(
        "funkwhale_api.tags.tasks.fetch_musicbrainz_genre",
        return_value=[{"id": mbid, "name": "ambient"}],
    )

    result = tasks.update_musicbrainz_genre()

    assert result["created"] == 0
    assert models.Tag.objects.filter(name="ambient").count() == 1


def test_update_musicbrainz_genre_attaches_mbid_to_existing_name(factories, mocker):
    mbid = str(uuid.uuid4())
    models.Tag.objects.create(name="metal")
    mocker.patch(
        "funkwhale_api.tags.tasks.fetch_musicbrainz_genre",
        return_value=[{"id": mbid, "name": "metal"}],
    )

    result = tasks.update_musicbrainz_genre()

    assert result["updated"] == 1
    tag = models.Tag.objects.get(name="metal")
    assert str(tag.mbid) == mbid
