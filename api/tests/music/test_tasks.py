import datetime
import os
import uuid

import pytest

from funkwhale_api.common import utils as common_utils
from funkwhale_api.music import licenses, metadata, models, signals, tasks

DATA_DIR = os.path.dirname(os.path.abspath(__file__))


# DATA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "uploads")


def test_can_create_track_from_file_metadata_no_mbid(db, mocker):
    add_tags = mocker.patch("funkwhale_api.tags.models.add_tags")
    metadata = {
        "title": "Test track",
        "artists": [{"name": "Test artist"}],
        "album": {"title": "Test album", "release_date": datetime.date(2012, 8, 15)},
        "position": 4,
        "disc_number": 2,
        "license": "Hello world: http://creativecommons.org/licenses/by-sa/4.0/",
        "copyright": "2018 Someone",
        "tags": ["Punk", "Rock"],
    }
    match_license = mocker.spy(licenses, "match")

    track = tasks.get_track_from_import_metadata(metadata)

    assert track.title == metadata["title"]
    assert track.mbid is None
    assert track.position == 4
    assert track.disc_number == 2
    assert track.license.code == "cc-by-sa-4.0"
    assert track.copyright == metadata["copyright"]
    assert track.album.title == metadata["album"]["title"]
    assert track.album.mbid is None
    assert track.album.release_date == datetime.date(2012, 8, 15)
    assert track.artist.name == metadata["artists"][0]["name"]
    assert track.artist.mbid is None
    match_license.assert_called_once_with(metadata["license"], metadata["copyright"])
    add_tags.assert_any_call(track, *metadata["tags"])
    add_tags.assert_any_call(track.artist, *[])
    add_tags.assert_any_call(track.album, *[])


def test_can_create_track_from_file_metadata_featuring(factories):
    metadata = {
        "title": "Whole Lotta Love",
        "position": 1,
        "disc_number": 1,
        "mbid": "508704c0-81d4-4c94-ba58-3fc0b7da23eb",
        "album": {
            "title": "Guitar Heaven: The Greatest Guitar Classics of All Time",
            "mbid": "d06f2072-4148-488d-af6f-69ab6539ddb8",
            "release_date": datetime.date(2010, 9, 17),
            "artists": [
                {"name": "Santana", "mbid": "9a3bf45c-347d-4630-894d-7cf3e8e0b632"}
            ],
        },
        "artists": [{"name": "Santana feat. Chris Cornell", "mbid": None}],
    }
    track = tasks.get_track_from_import_metadata(metadata)

    assert track.album.artist.name == "Santana"
    assert track.artist.name == "Santana feat. Chris Cornell"


def test_can_create_track_from_file_metadata_description(factories):
    metadata = {
        "title": "Whole Lotta Love",
        "position": 1,
        "disc_number": 1,
        "description": {"text": "hello there", "content_type": "text/plain"},
        "album": {"title": "Test album"},
        "artists": [{"name": "Santana"}],
    }
    track = tasks.get_track_from_import_metadata(metadata)

    assert track.description.text == "hello there"
    assert track.description.content_type == "text/plain"


def test_can_create_track_from_file_metadata_use_featuring(factories):
    metadata = {
        "title": "Whole Lotta Love",
        "position": 1,
        "disc_number": 1,
        "description": {"text": "hello there", "content_type": "text/plain"},
        "album": {"title": "Test album"},
        "artists": [{"name": "Santana"}, {"name": "Anatnas"}],
    }
    track = tasks.get_track_from_import_metadata(metadata)

    assert track.artist.name == "Anatnas"


def test_can_create_track_from_file_metadata_mbid(factories, mocker):
    metadata = {
        "title": "Test track",
        "artists": [
            {"name": "Test artist", "mbid": "9c6bddde-6228-4d9f-ad0d-03f6fcb19e13"}
        ],
        "album": {
            "title": "Test album",
            "release_date": datetime.date(2012, 8, 15),
            "mbid": "9c6bddde-6478-4d9f-ad0d-03f6fcb19e15",
            "artists": [
                {
                    "name": "Test album artist",
                    "mbid": "9c6bddde-6478-4d9f-ad0d-03f6fcb19e13",
                }
            ],
        },
        "position": 4,
        "mbid": "f269d497-1cc0-4ae4-a0c4-157ec7d73fcb",
        "cover_data": {"content": b"image_content", "mimetype": "image/png"},
    }

    track = tasks.get_track_from_import_metadata(metadata)

    assert track.title == metadata["title"]
    assert track.mbid == metadata["mbid"]
    assert track.position == 4
    assert track.disc_number is None
    assert track.album.title == metadata["album"]["title"]
    assert track.album.mbid == metadata["album"]["mbid"]
    assert str(track.album.artist.mbid) == metadata["album"]["artists"][0]["mbid"]
    assert track.album.artist.name == metadata["album"]["artists"][0]["name"]
    assert track.album.release_date == datetime.date(2012, 8, 15)
    assert track.artist.name == metadata["artists"][0]["name"]
    assert str(track.artist.mbid) == metadata["artists"][0]["mbid"]


def test_can_create_track_from_file_metadata_mbid_existing_album_artist(
    factories, mocker
):
    artist = factories["music.Artist"]()
    album = factories["music.Album"]()
    metadata = {
        "album": {
            "mbid": album.mbid,
            "title": "",
            "artists": [{"name": "", "mbid": album.artist.mbid}],
        },
        "title": "Hello",
        "position": 4,
        "artists": [{"mbid": artist.mbid, "name": ""}],
        "mbid": "f269d497-1cc0-4ae4-a0c4-157ec7d73fcb",
    }

    track = tasks.get_track_from_import_metadata(metadata)

    assert track.title == metadata["title"]
    assert track.mbid == metadata["mbid"]
    assert track.position == 4
    assert track.album == album
    assert track.artist == artist


def test_get_track_reuses_existing_library_album_without_mbid(factories):
    user = factories["users.User"]()
    library = factories["music.Library"](owner=user)
    album = factories["music.Album"](mbid=None, title="Shared Album")
    existing = factories["music.Track"](album=album)
    factories["music.Upload"](
        track=existing, library=library, import_status="finished"
    )

    metadata = {
        "title": "Late addition",
        "artists": [{"name": existing.artist.name}],
        "album": {"title": "Shared Album"},
        "position": 9,
    }
    track = tasks.get_track_from_import_metadata(metadata, attributed_to=user)

    assert track.album == album
    assert track != existing


def test_get_track_attaches_mbid_track_to_untagged_library_album(factories):
    user = factories["users.User"]()
    library = factories["music.Library"](owner=user)
    album = factories["music.Album"](mbid=None, title="Shared Album")
    existing = factories["music.Track"](album=album)
    factories["music.Upload"](
        track=existing, library=library, import_status="finished"
    )
    album_mbid = uuid.uuid4()

    metadata = {
        "title": "Missing track",
        "mbid": str(uuid.uuid4()),
        "artists": [{"name": existing.artist.name}],
        "album": {"title": "Shared Album", "mbid": str(album_mbid)},
        "position": 8,
    }
    track = tasks.get_track_from_import_metadata(metadata, attributed_to=user)

    assert track.album == album
    album.refresh_from_db()
    assert album.mbid == album_mbid


def test_get_track_reuses_album_by_release_mbid(factories):
    user = factories["users.User"]()
    library = factories["music.Library"](owner=user)
    album = factories["music.Album"](title="Shared Album")
    existing = factories["music.Track"](album=album)
    factories["music.Upload"](
        track=existing, library=library, import_status="finished"
    )

    metadata = {
        "title": "Missing track",
        "mbid": str(uuid.uuid4()),
        "artists": [{"name": existing.artist.name}],
        "album": {"title": "Shared Album", "mbid": str(album.mbid)},
        "position": 8,
    }
    track = tasks.get_track_from_import_metadata(metadata, attributed_to=user)

    assert track.album == album
    assert track != existing


def test_get_track_does_not_merge_distinct_album_mbids_by_title(factories):
    user = factories["users.User"]()
    library = factories["music.Library"](owner=user)
    album = factories["music.Album"](title="Shared Album")
    existing = factories["music.Track"](album=album)
    factories["music.Upload"](
        track=existing, library=library, import_status="finished"
    )

    metadata = {
        "title": "Other release",
        "artists": [{"name": existing.artist.name}],
        "album": {"title": "Shared Album", "mbid": str(uuid.uuid4())},
        "position": 1,
    }
    track = tasks.get_track_from_import_metadata(metadata, attributed_to=user)

    assert track.album != album


def test_get_track_assigns_album_when_existing_track_has_none(factories):
    album = factories["music.Album"]()
    track = factories["music.Track"](
        album=None,
        mbid="f269d497-1cc0-4ae4-a0c4-157ec7d73fcb",
        title="Orphan",
    )
    metadata = {
        "title": "Orphan",
        "mbid": str(track.mbid),
        "artists": [{"name": track.artist.name}],
        "album": {"title": album.title, "mbid": str(album.mbid)},
        "position": track.position or 1,
    }

    result = tasks.get_track_from_import_metadata(metadata)

    assert result.pk == track.pk
    result.refresh_from_db()
    assert result.album == album


def test_can_create_track_from_file_metadata_distinct_release_mbid(factories):
    """Cf https://dev.funkwhale.audio/funkwhale/funkwhale/issues/772"""
    artist = factories["music.Artist"]()
    album = factories["music.Album"](artist=artist)
    track = factories["music.Track"](album=album, artist=artist)
    metadata = {
        "artists": [{"name": artist.name, "mbid": artist.mbid}],
        "album": {"title": album.title, "mbid": str(uuid.uuid4())},
        "title": track.title,
        "position": 4,
        "fid": "https://hello",
    }

    new_track = tasks.get_track_from_import_metadata(metadata)

    # the returned track should be different from the existing one, and mapped
    # to a new album, because the albumid is different
    assert new_track.album != album
    assert new_track != track


def test_can_create_track_from_file_metadata_distinct_position(factories):
    """Cf https://dev.funkwhale.audio/funkwhale/funkwhale/issues/740"""
    artist = factories["music.Artist"]()
    album = factories["music.Album"](artist=artist)
    track = factories["music.Track"](album=album, artist=artist)
    metadata = {
        "artists": [{"name": artist.name, "mbid": artist.mbid}],
        "album": {"title": album.title, "mbid": album.mbid},
        "title": track.title,
        "position": track.position + 1,
    }

    new_track = tasks.get_track_from_import_metadata(metadata)

    assert new_track != track


def test_sort_candidates(factories):
    artist1 = factories["music.Artist"].build(mbid=None)
    artist2 = factories["music.Artist"].build()
    result = tasks.sort_candidates([artist1, artist2], ["mbid"])

    assert result == [artist2, artist1]


def test_upload_import(now, factories, temp_signal, mocker):
    populate_album_cover = mocker.patch(
        "funkwhale_api.music.tasks.populate_album_cover"
    )
    get_picture = mocker.patch("funkwhale_api.music.metadata.Metadata.get_picture")
    get_track_from_import_metadata = mocker.spy(tasks, "get_track_from_import_metadata")
    track = factories["music.Track"](album__attachment_cover=None)
    upload = factories["music.Upload"](
        track=None, import_metadata={"funkwhale": {"track": {"uuid": str(track.uuid)}}}
    )
    create_entries = mocker.patch(
        "funkwhale_api.music.models.TrackActor.create_entries"
    )

    with temp_signal(signals.upload_import_status_updated) as handler:
        tasks.process_upload(upload_id=upload.pk)

    upload.refresh_from_db()

    assert upload.track == track
    assert upload.import_status == "finished"
    assert upload.import_date == now
    get_picture.assert_called_once_with("cover_front", "other")
    populate_album_cover.assert_called_once_with(
        upload.track.album, source=upload.source
    )
    assert (
        get_track_from_import_metadata.call_args[-1]["attributed_to"]
        == upload.library.owner
    )
    handler.assert_called_once_with(
        upload=upload,
        old_status="pending",
        new_status="finished",
        sender=None,
        signal=signals.upload_import_status_updated,
    )
    create_entries.assert_called_once_with(
        library=upload.library,
        delete_existing=False,
        upload_and_track_ids=[(upload.pk, upload.track_id)],
    )


def test_upload_import_get_audio_data(factories, mocker):
    mocker.patch(
        "funkwhale_api.music.models.Upload.get_audio_data",
        return_value={"size": 23, "duration": 42, "bitrate": 66},
    )
    track = factories["music.Track"](album__with_cover=True)
    upload = factories["music.Upload"](
        track=None, import_metadata={"funkwhale": {"track": {"uuid": track.uuid}}}
    )

    tasks.process_upload(upload_id=upload.pk)

    upload.refresh_from_db()
    assert upload.size == 23
    assert upload.duration == 42
    assert upload.bitrate == 66


def test_upload_import_in_place(factories, mocker, settings):
    mocker.patch(
        "funkwhale_api.music.models.Upload.get_audio_data",
        return_value={"size": 23, "duration": 42, "bitrate": 66},
    )
    track = factories["music.Track"]()
    path = os.path.join(DATA_DIR, "test.ogg")
    settings.MUSIC_DIRECTORY_PATH = DATA_DIR
    upload = factories["music.Upload"](
        track=None,
        audio_file=None,
        source=f"file://{path}",
        import_metadata={"funkwhale": {"track": {"uuid": track.uuid}}},
    )

    tasks.process_upload(upload_id=upload.pk)

    upload.refresh_from_db()
    assert upload.size == 23
    assert upload.duration == 42
    assert upload.bitrate == 66
    assert upload.mimetype == "audio/ogg"


def test_upload_import_skip_existing_track_in_own_library(factories, temp_signal):
    track = factories["music.Track"]()
    library = factories["music.Library"]()
    existing = factories["music.Upload"](
        track=track,
        import_status="finished",
        library=library,
        import_metadata={"funkwhale": {"track": {"uuid": track.mbid}}},
    )
    duplicate = factories["music.Upload"](
        track=track,
        import_status="pending",
        library=library,
        import_metadata={"funkwhale": {"track": {"uuid": track.uuid}}},
    )
    with temp_signal(signals.upload_import_status_updated) as handler:
        tasks.process_upload(upload_id=duplicate.pk)

    duplicate.refresh_from_db()

    assert duplicate.import_status == "skipped"
    assert duplicate.import_details == {
        "code": "already_imported_in_owned_libraries",
        "duplicates": str(existing.uuid),
    }

    handler.assert_called_once_with(
        upload=duplicate,
        old_status="pending",
        new_status="skipped",
        sender=None,
        signal=signals.upload_import_status_updated,
    )


@pytest.mark.parametrize("import_status", ["draft", "errored", "finished"])
def test_process_upload_picks_ignore_non_pending_uploads(import_status, factories):
    upload = factories["music.Upload"](import_status=import_status)

    with pytest.raises(upload.DoesNotExist):
        tasks.process_upload(upload_id=upload.pk)


def test_process_upload_uncaught_exception_marks_upload_errored(factories, mocker):
    upload = factories["music.Upload"](track=None)
    mocker.patch(
        "funkwhale_api.music.tasks.get_track_from_import_metadata",
        side_effect=RuntimeError("boom"),
    )

    with pytest.raises(RuntimeError):
        tasks.process_upload(upload_id=upload.pk)

    upload.refresh_from_db()
    assert upload.import_status == "errored"
    assert upload.import_details["error_code"] == "unknown_error"
    assert "boom" in str(upload.import_details.get("detail", ""))


def test_process_upload_soft_timeout_marks_upload_errored(factories, mocker):
    from celery.exceptions import SoftTimeLimitExceeded

    upload = factories["music.Upload"](track=None)
    mocker.patch(
        "funkwhale_api.music.tasks.get_track_from_import_metadata",
        side_effect=SoftTimeLimitExceeded(),
    )

    with pytest.raises(SoftTimeLimitExceeded):
        tasks.process_upload(upload_id=upload.pk)

    upload.refresh_from_db()
    assert upload.import_status == "errored"
    assert upload.import_details["error_code"] == "import_timeout"


def test_process_upload_get_audio_data_failure_still_finishes(factories, mocker):
    track = factories["music.Track"](album__with_cover=True)
    upload = factories["music.Upload"](
        track=None, import_metadata={"funkwhale": {"track": {"uuid": str(track.uuid)}}}
    )
    mocker.patch(
        "funkwhale_api.music.models.Upload.get_audio_data",
        side_effect=OSError("mutagen exploded"),
    )

    tasks.process_upload(upload_id=upload.pk)

    upload.refresh_from_db()
    assert upload.import_status == "finished"
    assert upload.track == track


def test_process_upload_on_failure_marks_pending_upload(factories):
    upload = factories["music.Upload"](import_status="pending")
    tasks._process_upload_on_failure(
        RuntimeError("worker killed"),
        "task-id",
        (),
        {"upload_id": upload.pk},
        None,
    )
    upload.refresh_from_db()
    assert upload.import_status == "errored"
    assert upload.import_details["error_code"] == "unknown_error"


def test_process_upload_falls_back_to_import_metadata_when_tags_unreadable(
    factories, mocker
):
    mocker.patch(
        "funkwhale_api.music.metadata.Metadata",
        side_effect=ValueError("Cannot parse metadata from track.ogg"),
    )
    track = factories["music.Track"](album__with_cover=True)
    upload = factories["music.Upload"](
        track=None,
        import_metadata={"funkwhale": {"track": {"uuid": str(track.uuid)}}},
    )

    tasks.process_upload(upload_id=upload.pk)

    upload.refresh_from_db()
    assert upload.import_status == "finished"
    assert upload.track == track


def test_process_upload_fallback_uses_album_title_from_import_metadata(
    factories, mocker
):
    mocker.patch(
        "funkwhale_api.music.metadata.Metadata",
        side_effect=ValueError("Cannot parse metadata from track.ogg"),
    )
    mocker.patch(
        "funkwhale_api.music.models.Upload.get_audio_data",
        return_value={"size": 23, "duration": 42, "bitrate": 66},
    )
    user = factories["users.User"]()
    library = factories["music.Library"](owner=user)
    album = factories["music.Album"](mbid=None, title="Already Here")
    existing = factories["music.Track"](album=album)
    factories["music.Upload"](
        track=existing, library=library, import_status="finished"
    )
    upload = factories["music.Upload"](
        track=None,
        library=library,
        import_metadata={
            "title": "Bonus track",
            "album_title": "Already Here",
            "artist_name": existing.artist.name,
            "position": 12,
        },
    )

    tasks.process_upload(upload_id=upload.pk)

    upload.refresh_from_db()
    assert upload.import_status == "finished"
    assert upload.track.album == album


def test_process_upload_corrupt_file_marks_upload_errored(temp_signal, factories, tmp_path):
    # unparseable/corrupt files used to crash the task inside mutagen,
    # leaving the upload stuck in "pending" forever
    with open(os.path.join(DATA_DIR, "test.ogg"), "rb") as f:
        raw = f.read()
    # cut inside the Ogg comment header so mutagen cannot parse the file
    truncated = tmp_path / "truncated.ogg"
    truncated.write_bytes(raw[:100])

    upload = factories["music.Upload"](
        track=None, audio_file__from_path=str(truncated)
    )

    with temp_signal(signals.upload_import_status_updated):
        tasks.process_upload(upload_id=upload.pk)

    upload.refresh_from_db()

    assert upload.import_status == "errored"
    assert upload.import_details["error_code"] == "invalid_metadata"


def test_transcode_tasks_routed_to_dedicated_queue():
    # heavy ffmpeg encodes must never share the queue that serves imports
    for name in (
        "music.ensure_transcoded_version",
        "music.prewarm_upload_qualities",
        "music.schedule_quality_prewarm",
    ):
        task = tasks.celery.app.tasks[name]
        assert task.queue == "transcode", name


def test_upload_import_track_uuid(now, factories):
    track = factories["music.Track"](album__with_cover=True)
    upload = factories["music.Upload"](
        track=None, import_metadata={"funkwhale": {"track": {"uuid": track.uuid}}}
    )

    tasks.process_upload(upload_id=upload.pk)

    upload.refresh_from_db()

    assert upload.track == track
    assert upload.import_status == "finished"
    assert upload.import_date == now


def test_upload_import_skip_broadcast(now, factories, mocker):
    group_send = mocker.patch("funkwhale_api.common.channels.group_send")
    track = factories["music.Track"](album__with_cover=True)
    upload = factories["music.Upload"](
        track=None,
        import_metadata={
            "funkwhale": {"track": {"uuid": track.uuid}, "config": {"broadcast": False}}
        },
    )

    tasks.process_upload(upload_id=upload.pk)

    group_send.assert_not_called()


def test_upload_import_error(factories, now, temp_signal):
    upload = factories["music.Upload"](
        import_metadata={"funkwhale": {"track": {"uuid": uuid.uuid4()}}}
    )
    with temp_signal(signals.upload_import_status_updated) as handler:
        tasks.process_upload(upload_id=upload.pk)
    upload.refresh_from_db()

    assert upload.import_status == "errored"
    assert upload.import_date == now
    assert upload.import_details == {
        "error_code": "track_uuid_not_found",
        "detail": None,
    }
    handler.assert_called_once_with(
        upload=upload,
        old_status="pending",
        new_status="errored",
        sender=None,
        signal=signals.upload_import_status_updated,
    )


def test_upload_import_error_metadata(factories, now, temp_signal, mocker):
    path = os.path.join(DATA_DIR, "test.ogg")
    upload = factories["music.Upload"](audio_file__frompath=path)
    mocker.patch.object(
        metadata.AlbumField,
        "to_internal_value",
        side_effect=metadata.serializers.ValidationError("Hello"),
    )
    with temp_signal(signals.upload_import_status_updated) as handler:
        tasks.process_upload(upload_id=upload.pk)
    upload.refresh_from_db()

    assert upload.import_status == "errored"
    assert upload.import_date == now
    assert upload.import_details == {
        "error_code": "invalid_metadata",
        "detail": {"album": ["Hello"]},
        "file_metadata": metadata.Metadata(path).all(),
    }
    handler.assert_called_once_with(
        upload=upload,
        old_status="pending",
        new_status="errored",
        sender=None,
        signal=signals.upload_import_status_updated,
    )


def test_upload_import_updates_cover_if_no_cover(factories, mocker, now):
    populate_album_cover = mocker.patch(
        "funkwhale_api.music.tasks.populate_album_cover"
    )
    album = factories["music.Album"](attachment_cover=None)
    track = factories["music.Track"](album=album)
    upload = factories["music.Upload"](
        track=None, import_metadata={"funkwhale": {"track": {"uuid": track.uuid}}}
    )
    tasks.process_upload(upload_id=upload.pk)
    populate_album_cover.assert_called_once_with(album, source=None)


@pytest.mark.parametrize("ext,mimetype", [("jpg", "image/jpeg"), ("png", "image/png")])
def test_populate_album_cover_file_cover_separate_file(
    ext, mimetype, factories, mocker
):
    mocker.patch("funkwhale_api.music.tasks.IMAGE_TYPES", [(ext, mimetype)])
    image_path = os.path.join(DATA_DIR, f"cover.{ext}")
    with open(image_path, "rb") as f:
        image_content = f.read()
    album = factories["music.Album"](attachment_cover=None, mbid=None)

    attach_file = mocker.patch("funkwhale_api.common.utils.attach_file")
    mocker.patch("funkwhale_api.music.metadata.Metadata.get_picture", return_value=None)
    tasks.populate_album_cover(album=album, source="file://" + image_path)
    attach_file.assert_called_once_with(
        album, "attachment_cover", {"mimetype": mimetype, "content": image_content}
    )


def test_clean_transcoding_cache(preferences, now, factories):
    preferences["music__transcoding_cache_duration"] = 60
    # Non-ladder ad-hoc version (odd bitrate) past the retention window.
    u1 = factories["music.UploadVersion"](
        accessed_date=now - datetime.timedelta(minutes=61),
        bitrate=111000,
        mimetype="audio/mpeg",
    )
    u2 = factories["music.UploadVersion"](
        accessed_date=now - datetime.timedelta(minutes=59),
        bitrate=111000,
        mimetype="audio/mpeg",
    )
    # Quality-ladder rung must never be GC'd even when stale.
    ladder = factories["music.UploadVersion"](
        accessed_date=now - datetime.timedelta(minutes=61),
        bitrate=128000,
        mimetype="audio/mpeg",
    )

    tasks.clean_transcoding_cache()

    u2.refresh_from_db()
    ladder.refresh_from_db()

    with pytest.raises(u1.__class__.DoesNotExist):
        u1.refresh_from_db()


def test_clean_transcoding_cache_disabled_by_default(preferences, now, factories):
    preferences["music__transcoding_cache_duration"] = 0
    stale = factories["music.UploadVersion"](
        accessed_date=now - datetime.timedelta(days=30),
        bitrate=111000,
        mimetype="audio/mpeg",
    )
    tasks.clean_transcoding_cache()
    stale.refresh_from_db()


def test_schedule_quality_prewarm_enqueues(preferences, factories, mocker):
    preferences["music__transcoding_enabled"] = True
    preferences["music__auto_prewarm_qualities"] = True
    upload = factories["music.Upload"](
        import_status="finished",
        bitrate=900000,
        mimetype="audio/flac",
    )
    delayed = mocker.patch(
        "funkwhale_api.music.tasks.prewarm_upload_qualities.delay"
    )
    count = tasks.schedule_quality_prewarm(max_enqueue=10)
    assert count >= 1
    delayed.assert_any_call(upload.pk)


def test_get_prunable_tracks(factories):
    prunable_track = factories["music.Track"]()
    # track is still prunable if it has a skipped upload linked to it
    factories["music.Upload"](import_status="skipped", track=prunable_track)
    # non prunable tracks
    factories["music.Upload"]()
    factories["favorites.TrackFavorite"]()
    factories["history.Listening"]()
    factories["playlists.PlaylistTrack"]()

    assert list(tasks.get_prunable_tracks()) == [prunable_track]


def test_get_prunable_tracks_include_favorites(factories):
    prunable_track = factories["music.Track"]()
    favorited = factories["favorites.TrackFavorite"]().track
    # non prunable tracks
    factories["favorites.TrackFavorite"](track__playable=True)
    factories["music.Upload"]()
    factories["history.Listening"]()
    factories["playlists.PlaylistTrack"]()

    qs = tasks.get_prunable_tracks(exclude_favorites=False).order_by("id")
    assert list(qs) == [prunable_track, favorited]


def test_get_prunable_tracks_include_playlists(factories):
    prunable_track = factories["music.Track"]()
    in_playlist = factories["playlists.PlaylistTrack"]().track
    # non prunable tracks
    factories["favorites.TrackFavorite"]()
    factories["music.Upload"]()
    factories["history.Listening"]()
    factories["playlists.PlaylistTrack"](track__playable=True)

    qs = tasks.get_prunable_tracks(exclude_playlists=False).order_by("id")
    assert list(qs) == [prunable_track, in_playlist]


def test_get_prunable_tracks_include_listenings(factories):
    prunable_track = factories["music.Track"]()
    listened = factories["history.Listening"]().track
    # non prunable tracks
    factories["favorites.TrackFavorite"]()
    factories["music.Upload"]()
    factories["history.Listening"](track__playable=True)
    factories["playlists.PlaylistTrack"]()

    qs = tasks.get_prunable_tracks(exclude_listenings=False).order_by("id")
    assert list(qs) == [prunable_track, listened]


def test_get_prunable_albums(factories):
    prunable_album = factories["music.Album"]()
    # non prunable album
    factories["music.Track"]().album

    assert list(tasks.get_prunable_albums()) == [prunable_album]


def test_get_prunable_artists(factories):
    prunable_artist = factories["music.Artist"]()
    # non prunable artist
    non_prunable_artist = factories["music.Artist"]()
    non_prunable_album_artist = factories["music.Artist"]()
    factories["music.Track"](artist=non_prunable_artist)
    factories["music.Track"](album__artist=non_prunable_album_artist)

    assert list(tasks.get_prunable_artists()) == [prunable_artist]


def test_update_library_entity(factories, mocker):
    artist = factories["music.Artist"]()
    save = mocker.spy(artist, "save")

    tasks.update_library_entity(artist, {"name": "Hello"})
    save.assert_called_once_with(update_fields=["name"])

    artist.refresh_from_db()
    assert artist.name == "Hello"


@pytest.mark.parametrize(
    "name, ext, mimetype",
    [
        ("cover", "png", "image/png"),
        ("cover", "jpg", "image/jpeg"),
        ("cover", "jpeg", "image/jpeg"),
        ("folder", "png", "image/png"),
        ("folder", "jpg", "image/jpeg"),
        ("folder", "jpeg", "image/jpeg"),
    ],
)
def test_get_cover_from_fs(name, ext, mimetype, tmpdir):
    cover_path = os.path.join(tmpdir, f"{name}.{ext}")
    content = "Hello"
    with open(cover_path, "w") as f:
        f.write(content)

    expected = {"mimetype": mimetype, "content": content.encode()}
    assert tasks.get_cover_from_fs(tmpdir) == expected


@pytest.mark.parametrize("name", ["cover.gif", "folder.gif"])
def test_get_cover_from_fs_ignored(name, tmpdir):
    cover_path = os.path.join(tmpdir, name)
    content = "Hello"
    with open(cover_path, "w") as f:
        f.write(content)

    assert tasks.get_cover_from_fs(tmpdir) is None


def test_get_track_from_import_metadata_with_forced_values(factories, mocker, faker):
    forced_values = {
        "title": "Real title",
        "artist": factories["music.Artist"](),
        "album": None,
        "license": factories["music.License"](),
        "position": 3,
        "copyright": "Real copyright",
        "mbid": faker.uuid4(),
        "tags": ["hello", "world"],
    }
    metadata = {
        "title": "Test track",
        "artists": [{"name": "Test artist"}],
        "album": {"title": "Test album", "release_date": datetime.date(2012, 8, 15)},
        "position": 4,
        "disc_number": 2,
        "copyright": "2018 Someone",
        "tags": ["foo", "bar"],
    }

    track = tasks.get_track_from_import_metadata(metadata, **forced_values)

    assert track.title == forced_values["title"]
    assert track.mbid == forced_values["mbid"]
    assert track.position == forced_values["position"]
    assert track.disc_number == metadata["disc_number"]
    assert track.copyright == forced_values["copyright"]
    assert track.album == forced_values["album"]
    assert track.artist == forced_values["artist"]
    assert track.license == forced_values["license"]
    assert (
        sorted(track.tagged_items.values_list("tag__name", flat=True))
        == forced_values["tags"]
    )


def test_get_track_from_import_metadata_with_forced_values_album(
    factories, mocker, faker
):
    channel = factories["audio.Channel"]()
    album = factories["music.Album"](artist=channel.artist, with_cover=True)

    forced_values = {
        "title": "Real title",
        "album": album.pk,
    }
    upload = factories["music.Upload"](
        import_metadata=forced_values, library=channel.library, track=None
    )
    tasks.process_upload(upload_id=upload.pk)
    upload.refresh_from_db()
    assert upload.import_status == "finished"

    assert upload.track.title == forced_values["title"]
    assert upload.track.album == album
    assert upload.track.artist == channel.artist


def test_process_channel_upload_forces_artist(factories, mocker, faker):
    channel = factories["audio.Channel"]()
    update_modification_date = mocker.spy(common_utils, "update_modification_date")

    import_metadata = {
        "title": "Real title",
        "position": 3,
        "copyright": "Real copyright",
        "tags": ["hello", "world"],
        "description": "my description",
    }
    expected_forced_values = import_metadata.copy()
    expected_forced_values["artist"] = channel.artist
    upload = factories["music.Upload"](
        track=None, import_metadata=import_metadata, library=channel.library
    )
    get_track_from_import_metadata = mocker.spy(tasks, "get_track_from_import_metadata")

    tasks.process_upload(upload_id=upload.pk)

    upload.refresh_from_db()

    expected_final_metadata = tasks.collections.ChainMap(
        {"upload_source": None},
        expected_forced_values,
        {"funkwhale": {}},
    )
    assert upload.import_status == "finished"
    get_track_from_import_metadata.assert_called_once_with(
        expected_final_metadata,
        attributed_to=channel.owner,
        **expected_forced_values,
    )

    assert upload.track.description.content_type == "text/markdown"
    assert upload.track.description.text == import_metadata["description"]
    assert upload.track.title == import_metadata["title"]
    assert upload.track.position == import_metadata["position"]
    assert upload.track.copyright == import_metadata["copyright"]
    assert upload.track.get_tags() == import_metadata["tags"]
    assert upload.track.artist == channel.artist

    update_modification_date.assert_called_once_with(channel.artist)


def test_process_upload_uses_import_metadata_if_valid(factories, mocker):
    track = factories["music.Track"](album__with_cover=True)
    import_metadata = {"title": "hello", "funkwhale": {"foo": "bar"}}
    upload = factories["music.Upload"](track=None, import_metadata=import_metadata)
    get_track_from_import_metadata = mocker.patch.object(
        tasks, "get_track_from_import_metadata", return_value=track
    )
    tasks.process_upload(upload_id=upload.pk)

    serializer = tasks.metadata.TrackMetadataSerializer(
        data=tasks.metadata.Metadata(upload.get_audio_file())
    )
    assert serializer.is_valid() is True
    audio_metadata = serializer.validated_data

    expected_final_metadata = tasks.collections.ChainMap(
        {"upload_source": None},
        audio_metadata,
        {"funkwhale": import_metadata["funkwhale"]},
    )
    get_track_from_import_metadata.assert_called_once_with(
        expected_final_metadata, attributed_to=upload.library.owner, title="hello"
    )


def test_process_upload_skips_import_metadata_if_invalid(factories, mocker):
    track = factories["music.Track"](album__with_cover=True)
    import_metadata = {"title": None, "funkwhale": {"foo": "bar"}}
    upload = factories["music.Upload"](track=None, import_metadata=import_metadata)
    get_track_from_import_metadata = mocker.patch.object(
        tasks, "get_track_from_import_metadata", return_value=track
    )
    tasks.process_upload(upload_id=upload.pk)

    serializer = tasks.metadata.TrackMetadataSerializer(
        data=tasks.metadata.Metadata(upload.get_audio_file())
    )
    assert serializer.is_valid() is True
    audio_metadata = serializer.validated_data

    expected_final_metadata = tasks.collections.ChainMap(
        {"upload_source": None},
        audio_metadata,
        {"funkwhale": import_metadata["funkwhale"]},
    )
    get_track_from_import_metadata.assert_called_once_with(
        expected_final_metadata, attributed_to=upload.library.owner
    )


def test_tag_albums_from_tracks(queryset_equal_queries, factories, mocker):
    get_tags_from_foreign_key = mocker.patch(
        "funkwhale_api.tags.tasks.get_tags_from_foreign_key"
    )
    add_tags_batch = mocker.patch("funkwhale_api.tags.tasks.add_tags_batch")

    expected_queryset = (
        models.Album.objects.filter(tagged_items__isnull=True)
        .values_list("id", flat=True)
        .order_by("id")
    )
    tasks.albums_set_tags_from_tracks(ids=[1, 2])
    get_tags_from_foreign_key.assert_called_once_with(
        ids=expected_queryset.filter(pk__in=[1, 2]),
        foreign_key_model=models.Track,
        foreign_key_attr="album",
    )

    add_tags_batch.assert_called_once_with(
        get_tags_from_foreign_key.return_value,
        model=models.Album,
    )


def test_tag_artists_from_tracks(queryset_equal_queries, factories, mocker):
    get_tags_from_foreign_key = mocker.patch(
        "funkwhale_api.tags.tasks.get_tags_from_foreign_key"
    )
    add_tags_batch = mocker.patch("funkwhale_api.tags.tasks.add_tags_batch")

    expected_queryset = (
        models.Artist.objects.filter(tagged_items__isnull=True)
        .values_list("id", flat=True)
        .order_by("id")
    )
    tasks.artists_set_tags_from_tracks(ids=[1, 2])
    get_tags_from_foreign_key.assert_called_once_with(
        ids=expected_queryset.filter(pk__in=[1, 2]),
        foreign_key_model=models.Track,
        foreign_key_attr="artist_credit__artist",
    )

    add_tags_batch.assert_called_once_with(
        get_tags_from_foreign_key.return_value,
        model=models.Artist,
    )


def test_can_download_image_file_for_album_mbid(binary_cover, mocker, factories):
    mocker.patch(
        "funkwhale_api.musicbrainz.api.images.get_front", return_value=binary_cover
    )
    # client._api.get_image_front('55ea4f82-b42b-423e-a0e5-290ccdf443ed')
    album = factories["music.Album"](mbid="55ea4f82-b42b-423e-a0e5-290ccdf443ed")
    tasks.populate_album_cover(album, replace=True)

    assert album.attachment_cover.file.read() == binary_cover
    assert album.attachment_cover.mimetype == "image/jpeg"


def test_can_import_track_with_same_mbid_in_different_albums(factories, mocker):
    artist = factories["music.Artist"]()
    upload = factories["music.Upload"](
        playable=True, track__artist=artist, track__album__artist=artist
    )
    assert upload.track.mbid is not None
    data = {
        "title": upload.track.title,
        "artists": [{"name": artist.name, "mbid": artist.mbid}],
        "album": {
            "title": "The Slip",
            "mbid": uuid.UUID("12b57d46-a192-499e-a91f-7da66790a1c1"),
            "release_date": datetime.date(2008, 5, 5),
            "artists": [{"name": artist.name, "mbid": artist.mbid}],
        },
        "position": 1,
        "disc_number": 1,
        "mbid": upload.track.mbid,
    }

    mocker.patch.object(metadata.TrackMetadataSerializer, "validated_data", data)
    mocker.patch.object(tasks, "populate_album_cover")

    new_upload = factories["music.Upload"](library=upload.library)

    tasks.process_upload(upload_id=new_upload.pk)

    new_upload.refresh_from_db()

    assert new_upload.import_status == "finished"


def test_import_track_with_same_mbid_in_same_albums_skipped(factories, mocker):
    artist = factories["music.Artist"]()
    upload = factories["music.Upload"](
        playable=True, track__artist=artist, track__album__artist=artist
    )
    assert upload.track.mbid is not None
    data = {
        "title": upload.track.title,
        "artists": [{"name": artist.name, "mbid": artist.mbid}],
        "album": {
            "title": upload.track.album.title,
            "mbid": upload.track.album.mbid,
            "artists": [{"name": artist.name, "mbid": artist.mbid}],
        },
        "position": 1,
        "disc_number": 1,
        "mbid": upload.track.mbid,
    }

    mocker.patch.object(metadata.TrackMetadataSerializer, "validated_data", data)
    mocker.patch.object(tasks, "populate_album_cover")

    new_upload = factories["music.Upload"](library=upload.library)

    tasks.process_upload(upload_id=new_upload.pk)

    new_upload.refresh_from_db()

    assert new_upload.import_status == "skipped"


def test_can_import_track_with_same_position_in_different_discs(factories, mocker):
    upload = factories["music.Upload"](playable=True)
    artist_data = [
        {
            "name": upload.track.album.artist.name,
            "mbid": upload.track.album.artist.mbid,
        }
    ]
    data = {
        "title": upload.track.title,
        "artists": artist_data,
        "album": {
            "title": "The Slip",
            "mbid": upload.track.album.mbid,
            "release_date": datetime.date(2008, 5, 5),
            "artists": artist_data,
        },
        "position": upload.track.position,
        "disc_number": 2,
        "mbid": None,
    }

    mocker.patch.object(metadata.TrackMetadataSerializer, "validated_data", data)
    mocker.patch.object(tasks, "populate_album_cover")

    new_upload = factories["music.Upload"](library=upload.library)

    tasks.process_upload(upload_id=new_upload.pk)

    new_upload.refresh_from_db()

    assert new_upload.import_status == "finished"


def test_can_import_track_with_same_position_in_same_discs_skipped(factories, mocker):
    upload = factories["music.Upload"](playable=True)
    artist_data = [
        {
            "name": upload.track.album.artist.name,
            "mbid": upload.track.album.artist.mbid,
        }
    ]
    data = {
        "title": upload.track.title,
        "artists": artist_data,
        "album": {
            "title": "The Slip",
            "mbid": upload.track.album.mbid,
            "release_date": datetime.date(2008, 5, 5),
            "artists": artist_data,
        },
        "position": upload.track.position,
        "disc_number": upload.track.disc_number,
        "mbid": None,
    }

    mocker.patch.object(metadata.TrackMetadataSerializer, "validated_data", data)
    mocker.patch.object(tasks, "populate_album_cover")

    new_upload = factories["music.Upload"](library=upload.library)

    tasks.process_upload(upload_id=new_upload.pk)

    new_upload.refresh_from_db()

    assert new_upload.import_status == "skipped"


def test_update_track_metadata(factories):
    track = factories["music.Track"]()
    data = {
        "title": "Peer Gynt Suite no. 1, op. 46: I. Morning",
        "artist": "Edvard Grieg",
        "album_artist": "Edvard Grieg; Musopen Symphony Orchestra",
        "album": "Peer Gynt Suite no. 1, op. 46",
        "date": "2012-08-15",
        "position": "4",
        "disc_number": "2",
        "musicbrainz_albumid": "a766da8b-8336-47aa-a3ee-371cc41ccc75",
        "mbid": "bd21ac48-46d8-4e78-925f-d9cc2a294656",
        "musicbrainz_artistid": "013c8e5b-d72a-4cd3-8dee-6c64d6125823",
        "musicbrainz_albumartistid": "013c8e5b-d72a-4cd3-8dee-6c64d6125823;5b4d7d2d-36df-4b38-95e3-a964234f520f",
        "license": "Dummy license: http://creativecommons.org/licenses/by-sa/4.0/",
        "copyright": "Someone",
        "comment": "hello there",
        "genre": "classical",
    }
    tasks.update_track_metadata(metadata.FakeMetadata(data), track)

    track.refresh_from_db()

    assert track.title == data["title"]
    assert track.position == int(data["position"])
    assert track.disc_number == int(data["disc_number"])
    assert track.license.code == "cc-by-sa-4.0"
    assert track.copyright == data["copyright"]
    assert str(track.mbid) == data["mbid"]
    assert track.album.title == data["album"]
    assert track.album.release_date == datetime.date(2012, 8, 15)
    assert str(track.album.mbid) == data["musicbrainz_albumid"]
    assert track.artist.name == data["artist"]
    assert str(track.artist.mbid) == data["musicbrainz_artistid"]
    assert track.album.artist.name == "Edvard Grieg"
    assert str(track.album.artist.mbid) == "013c8e5b-d72a-4cd3-8dee-6c64d6125823"
    assert sorted(track.tagged_items.values_list("tag__name", flat=True)) == [
        "classical"
    ]


def test_fs_import_not_pending(factories):
    with pytest.raises(ValueError):
        tasks.fs_import(
            library_id=factories["music.Library"]().pk,
            path="path",
            import_reference="test",
        )


def test_fs_import(factories, cache, mocker, settings):
    _handle = mocker.spy(tasks.import_files.Command, "_handle")
    cache.set("fs-import:status", "pending")
    library = factories["music.Library"]()
    tasks.fs_import(library_id=library.pk, path="path", import_reference="test")
    assert _handle.call_args[1] == {
        "recursive": True,
        "path": [settings.MUSIC_DIRECTORY_PATH + "/path"],
        "library_id": str(library.uuid),
        "update_cache": True,
        "in_place": True,
        "reference": "test",
        "watch": False,
        "interactive": False,
        "batch_size": 1000,
        "async_": False,
        "prune": True,
        "broadcast": False,
        "outbox": False,
        "exit_on_failure": False,
        "replace": False,
        "verbosity": 1,
    }
    assert cache.get("fs-import:status") == "finished"
    assert "Pruning dangling tracks" in cache.get("fs-import:logs")[-1]


def test_upload_checks_mbid_tag(temp_signal, factories, mocker, preferences):
    preferences["music__only_allow_musicbrainz_tagged_files"] = True
    mocker.patch("funkwhale_api.music.tasks.populate_album_cover")
    mocker.patch("funkwhale_api.music.metadata.Metadata.get_picture")
    track = factories["music.Track"](album__attachment_cover=None, mbid=None)
    path = os.path.join(DATA_DIR, "with_cover.opus")

    upload = factories["music.Upload"](
        track=None,
        audio_file__from_path=path,
        import_metadata={"funkwhale": {"track": {"uuid": str(track.uuid)}}},
    )
    mocker.patch("funkwhale_api.music.models.TrackActor.create_entries")

    with temp_signal(signals.upload_import_status_updated):
        tasks.process_upload(upload_id=upload.pk)

    upload.refresh_from_db()

    assert upload.import_status == "errored"
    assert upload.import_details == {
        "error_code": "missing_musicbrainz_id",
        "detail": (
            "Only content tagged with a MusicBrainz ID is permitted on this "
            "pod. Tag your files with MusicBrainz Picard, or use the "
            "MusicBrainz lookup in the upload form before uploading."
        ),
    }


def test_upload_checks_mbid_tag_pass(temp_signal, factories, mocker, preferences):
    preferences["music__only_allow_musicbrainz_tagged_files"] = True
    mocker.patch("funkwhale_api.music.tasks.populate_album_cover")
    mocker.patch("funkwhale_api.music.metadata.Metadata.get_picture")
    track = factories["music.Track"](album__attachment_cover=None, mbid=None)
    path = os.path.join(DATA_DIR, "test.mp3")

    upload = factories["music.Upload"](
        track=None,
        audio_file__from_path=path,
        import_metadata={"funkwhale": {"track": {"uuid": str(track.uuid)}}},
    )
    mocker.patch("funkwhale_api.music.models.TrackActor.create_entries")

    with temp_signal(signals.upload_import_status_updated):
        tasks.process_upload(upload_id=upload.pk)

    upload.refresh_from_db()

    assert upload.import_status == "finished"
