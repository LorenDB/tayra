import os

import pytest
from django.utils import timezone

from funkwhale_api.common import utils as common_utils
from funkwhale_api.music import importers, models

DATA_DIR = os.path.dirname(os.path.abspath(__file__))


def test_can_store_release_group_id_on_album(factories):
    album = factories["music.Album"]()
    assert album.release_group_id is not None


def test_album_duration_updated_when_uploads_change(factories):
    album = factories["music.Album"]()
    track1 = factories["music.Track"](album=album)
    track2 = factories["music.Track"](album=album)

    upload1 = factories["music.Upload"](track=track1, duration=100)
    factories["music.Upload"](track=track2, duration=50)
    album.refresh_from_db()
    assert album.duration == 150

    # Second upload on same track does not double-count (lowest upload id wins).
    factories["music.Upload"](track=track1, duration=999)
    album.refresh_from_db()
    assert album.duration == 150

    upload1.duration = 200
    upload1.save(update_fields=["duration"])
    album.refresh_from_db()
    assert album.duration == 250

    upload1.delete()
    album.refresh_from_db()
    # After deleting the first upload on track1, the 999s one remains for track1.
    assert album.duration == 999 + 50


def test_album_duration_updated_when_track_moves_album(factories):
    album_a = factories["music.Album"]()
    album_b = factories["music.Album"]()
    track = factories["music.Track"](album=album_a)
    factories["music.Upload"](track=track, duration=120)

    album_a.refresh_from_db()
    album_b.refresh_from_db()
    assert album_a.duration == 120
    assert album_b.duration == 0

    track.album = album_b
    track.save(update_fields=["album"])

    album_a.refresh_from_db()
    album_b.refresh_from_db()
    assert album_a.duration == 0
    assert album_b.duration == 120


def test_compute_album_duration_matches_stored_duration(factories):
    album = factories["music.Album"]()
    track1 = factories["music.Track"](album=album)
    track2 = factories["music.Track"](album=album)
    factories["music.Upload"](track=track1, duration=21)
    factories["music.Upload"](track=track1, duration=21)
    factories["music.Upload"](track=track2, duration=21)

    assert models.compute_album_duration(album.pk) == 42
    album.refresh_from_db()
    assert album.duration == 42


def test_import_album_stores_release_group(factories):
    album_data = {
        "artist-credit": [
            {
                "artist": {
                    "disambiguation": "George Shaw",
                    "id": "62c3befb-6366-4585-b256-809472333801",
                    "name": "Adhesive Wombat",
                    "sort-name": "Wombat, Adhesive",
                }
            }
        ],
        "artist-credit-phrase": "Adhesive Wombat",
        "country": "XW",
        "date": "2013-06-05",
        "id": "a50d2a81-2a50-484d-9cb4-b9f6833f583e",
        "status": "Official",
        "title": "Marsupial Madness",
        "release-group": {"id": "447b4979-2178-405c-bfe6-46bf0b09e6c7"},
    }
    artist = factories["music.Artist"](
        mbid=album_data["artist-credit"][0]["artist"]["id"]
    )
    cleaned_data = models.Album.clean_musicbrainz_data(album_data)
    album = importers.load(models.Album, cleaned_data, album_data, import_hooks=[])

    assert album.release_group_id == album_data["release-group"]["id"]
    assert album.artist == artist


def test_import_track_from_release(factories, mocker):
    album = factories["music.Album"](mbid="430347cb-0879-3113-9fde-c75b658c298e")
    artist = factories["music.Artist"](mbid="a5211c65-2465-406b-93ec-213588869dc1")
    album_data = {
        "release": {
            "id": album.mbid,
            "title": "Daydream Nation",
            "status": "Official",
            "medium-count": 1,
            "medium-list": [
                {
                    "position": "1",
                    "format": "CD",
                    "track-list": [
                        {
                            "id": "03baca8b-855a-3c05-8f3d-d3235287d84d",
                            "position": "4",
                            "number": "4",
                            "length": "417973",
                            "recording": {
                                "id": "2109e376-132b-40ad-b993-2bb6812e19d4",
                                "title": "Teen Age Riot",
                                "length": "417973",
                                "artist-credit": [
                                    {"artist": {"id": artist.mbid, "name": artist.name}}
                                ],
                            },
                            "track_or_recording_length": "417973",
                        }
                    ],
                    "track-count": 1,
                }
            ],
        }
    }
    mocked_get = mocker.patch(
        "funkwhale_api.musicbrainz.api.releases.get", return_value=album_data
    )
    track_data = album_data["release"]["medium-list"][0]["track-list"][0]
    track = models.Track.get_or_create_from_release(
        "430347cb-0879-3113-9fde-c75b658c298e", track_data["recording"]["id"]
    )[0]
    mocked_get.assert_called_once_with(album.mbid, includes=models.Album.api_includes)
    assert track.title == track_data["recording"]["title"]
    assert track.mbid == track_data["recording"]["id"]
    assert track.album == album
    assert track.artist == artist
    assert track.position == int(track_data["position"])


def test_import_track_with_different_artist_than_release(factories, mocker):
    album = factories["music.Album"](mbid="430347cb-0879-3113-9fde-c75b658c298e")
    recording_data = {
        "recording": {
            "id": "94ab07eb-bdf3-4155-b471-ba1dc85108bf",
            "title": "Flaming Red Hair",
            "length": "159000",
            "artist-credit": [
                {
                    "artist": {
                        "id": "a5211c65-2465-406b-93ec-213588869dc1",
                        "name": "Plan 9",
                        "sort-name": "Plan 9",
                        "disambiguation": "New Zealand group",
                    }
                }
            ],
            "release-list": [
                {
                    "id": album.mbid,
                    "title": "The Lord of the Rings: The Fellowship of the Ring - The Complete Recordings",
                    "status": "Official",
                    "quality": "normal",
                    "text-representation": {"language": "eng", "script": "Latn"},
                    "artist-credit": [
                        {
                            "artist": {
                                "id": "9b58672a-e68e-4972-956e-a8985a165a1f",
                                "name": "Howard Shore",
                                "sort-name": "Shore, Howard",
                            }
                        }
                    ],
                    "date": "2005-12-13",
                    "country": "US",
                    "release-event-count": 1,
                    "barcode": "093624945420",
                    "artist-credit-phrase": "Howard Shore",
                }
            ],
            "release-count": 3,
            "artist-credit-phrase": "Plan 9",
        }
    }
    artist = factories["music.Artist"](mbid="a5211c65-2465-406b-93ec-213588869dc1")
    mocker.patch(
        "funkwhale_api.musicbrainz.api.recordings.get", return_value=recording_data
    )

    track = models.Track.get_or_create_from_api(recording_data["recording"]["id"])[0]
    assert track.title == recording_data["recording"]["title"]
    assert track.mbid == recording_data["recording"]["id"]
    assert track.album == album
    assert track.artist == artist


@pytest.mark.parametrize(
    "extension,mimetype", [("ogg", "audio/ogg"), ("mp3", "audio/mpeg")]
)
def test_audio_track_mime_type(extension, mimetype, factories):
    name = ".".join(["test", extension])
    path = os.path.join(DATA_DIR, name)
    upload = factories["music.Upload"](audio_file__from_path=path, mimetype=None)

    assert upload.mimetype == mimetype


@pytest.mark.parametrize("name", ["test.ogg", "test.mp3"])
def test_audio_track_checksum(name, factories):
    path = os.path.join(DATA_DIR, name)
    upload = factories["music.Upload"](audio_file__from_path=path, mimetype=None)

    with open(path, "rb") as f:
        expected = common_utils.get_file_hash(f)
    assert upload.checksum == expected


def test_upload_file_name(factories):
    name = "test.mp3"
    path = os.path.join(DATA_DIR, name)
    upload = factories["music.Upload"](audio_file__from_path=path, mimetype=None)
    assert upload.filename == upload.track.full_name + ".mp3"


def test_track_get_file_size(factories):
    name = "test.mp3"
    path = os.path.join(DATA_DIR, name)
    upload = factories["music.Upload"](audio_file__from_path=path)

    assert upload.get_file_size() == 297745


def test_track_get_file_size_in_place(factories, settings):
    name = "test.mp3"
    path = os.path.join(DATA_DIR, name)
    settings.MUSIC_DIRECTORY_PATH = DATA_DIR
    upload = factories["music.Upload"](in_place=True, source=f"file://{path}")

    assert upload.get_file_size() == 297745


def test_library(factories):
    now = timezone.now()
    library = factories["music.Library"](
        name="Hello world", description="hello", privacy_level="instance"
    )

    assert library.creation_date >= now
    assert library.uploads.count() == 0
    assert library.uuid is not None
    assert library.owner is not None


@pytest.mark.parametrize(
    "status,expected",
    [("pending", False), ("errored", False), ("finished", True), ("skipped", True)],
)
def test_playable_by_correct_status(status, expected, factories):
    upload = factories["music.Upload"](
        library__privacy_level="everyone", import_status=status
    )
    queryset = upload.library.uploads.playable_by(None)
    match = upload in list(queryset)
    assert match is expected


@pytest.mark.parametrize(
    "privacy_level,expected", [("me", True), ("instance", True), ("everyone", True)]
)
def test_playable_by_owner(privacy_level, expected, factories):
    upload = factories["music.Upload"](
        library__privacy_level=privacy_level,
        import_status="finished",
    )
    queryset = upload.library.uploads.playable_by(upload.library.owner)
    match = upload in list(queryset)
    assert match is expected


@pytest.mark.parametrize(
    "privacy_level,expected", [("me", False), ("instance", True), ("everyone", True)]
)
def test_playable_by_other_user(privacy_level, expected, factories):
    upload = factories["music.Upload"](
        library__privacy_level=privacy_level,
        import_status="finished",
    )
    other_user = factories["users.User"]()
    queryset = upload.library.uploads.playable_by(other_user)
    match = upload in list(queryset)
    assert match is expected


@pytest.mark.parametrize(
    "privacy_level,expected", [("me", False), ("instance", False), ("everyone", True)]
)
def test_playable_by_anonymous(privacy_level, expected, factories):
    upload = factories["music.Upload"](
        library__privacy_level=privacy_level,
        import_status="finished",
    )
    queryset = upload.library.uploads.playable_by(None)
    match = upload in list(queryset)
    assert match is expected


@pytest.mark.parametrize("approved", [True, False])
def test_playable_by_subscriber(approved, factories):
    upload = factories["music.Upload"](
        library__privacy_level="me", import_status="finished"
    )
    channel = factories["audio.Channel"](
        library=upload.library, owner=upload.library.owner
    )
    user = factories["users.User"]()
    factories["audio.Subscription"](
        channel=channel, user=user, approved=approved
    )
    queryset = upload.library.uploads.playable_by(user)
    match = upload in list(queryset)
    expected = approved
    assert match is expected


@pytest.mark.parametrize(
    "privacy_level,expected", [("me", True), ("instance", True), ("everyone", True)]
)
def test_track_playable_by_owner(privacy_level, expected, factories):
    upload = factories["music.Upload"](import_status="finished")
    queryset = models.Track.objects.playable_by(
        upload.library.owner
    ).annotate_playable_by_user(upload.library.owner)
    match = upload.track in list(queryset)
    assert match is expected
    if expected:
        assert bool(queryset.first().is_playable_by_user) is expected


@pytest.mark.parametrize(
    "privacy_level,expected", [("me", False), ("instance", True), ("everyone", True)]
)
def test_track_playable_by_other_user(privacy_level, expected, factories):
    upload = factories["music.Upload"](
        library__privacy_level=privacy_level,
        import_status="finished",
    )
    other_user = factories["users.User"]()
    queryset = models.Track.objects.playable_by(
        other_user
    ).annotate_playable_by_user(other_user)
    match = upload.track in list(queryset)
    assert match is expected
    if expected:
        assert bool(queryset.first().is_playable_by_user) is expected


@pytest.mark.parametrize(
    "privacy_level,expected", [("me", False), ("instance", False), ("everyone", True)]
)
def test_track_playable_by_anonymous(privacy_level, expected, factories):
    upload = factories["music.Upload"](
        library__privacy_level=privacy_level,
        import_status="finished",
    )
    queryset = models.Track.objects.playable_by(None).annotate_playable_by_user(None)
    match = upload.track in list(queryset)
    assert match is expected
    if expected:
        assert bool(queryset.first().is_playable_by_user) is expected


@pytest.mark.parametrize(
    "privacy_level,expected", [("me", True), ("instance", True), ("everyone", True)]
)
def test_album_playable_by_owner(privacy_level, expected, factories):
    upload = factories["music.Upload"](import_status="finished")

    queryset = models.Album.objects.playable_by(
        upload.library.owner
    ).annotate_playable_by_user(upload.library.owner)
    match = upload.track.album in list(queryset)
    assert match is expected
    if expected:
        assert bool(queryset.first().is_playable_by_user) is expected


@pytest.mark.parametrize(
    "privacy_level,expected", [("me", False), ("instance", True), ("everyone", True)]
)
def test_album_playable_by_other_user(privacy_level, expected, factories):
    upload = factories["music.Upload"](
        library__privacy_level=privacy_level,
        import_status="finished",
    )
    other_user = factories["users.User"]()
    queryset = models.Album.objects.playable_by(
        other_user
    ).annotate_playable_by_user(other_user)
    match = upload.track.album in list(queryset)
    assert match is expected
    if expected:
        assert bool(queryset.first().is_playable_by_user) is expected


@pytest.mark.parametrize(
    "privacy_level,expected", [("me", False), ("instance", False), ("everyone", True)]
)
def test_album_playable_by_anonymous(privacy_level, expected, factories):
    upload = factories["music.Upload"](
        library__privacy_level=privacy_level,
        import_status="finished",
    )
    queryset = models.Album.objects.playable_by(None).annotate_playable_by_user(None)
    match = upload.track.album in list(queryset)
    assert match is expected
    if expected:
        assert bool(queryset.first().is_playable_by_user) is expected


@pytest.mark.parametrize(
    "privacy_level,expected", [("me", True), ("instance", True), ("everyone", True)]
)
def test_artist_playable_by_owner(privacy_level, expected, factories):
    upload = factories["music.Upload"](
        library__privacy_level=privacy_level,
        import_status="finished",
    )

    queryset = models.Artist.objects.playable_by(
        upload.library.owner
    ).annotate_playable_by_user(upload.library.owner)
    match = upload.track.artist in list(queryset)
    assert match is expected
    if expected:
        assert bool(queryset.first().is_playable_by_user) is expected


@pytest.mark.parametrize(
    "privacy_level,expected", [("me", False), ("instance", True), ("everyone", True)]
)
def test_artist_playable_by_other_user(privacy_level, expected, factories):
    upload = factories["music.Upload"](
        library__privacy_level=privacy_level,
        import_status="finished",
    )
    other_user = factories["users.User"]()
    queryset = models.Artist.objects.playable_by(
        other_user
    ).annotate_playable_by_user(other_user)
    match = upload.track.artist in list(queryset)
    assert match is expected
    if expected:
        assert bool(queryset.first().is_playable_by_user) is expected


@pytest.mark.parametrize(
    "privacy_level,expected", [("me", False), ("instance", False), ("everyone", True)]
)
def test_artist_playable_by_anonymous(privacy_level, expected, factories):
    upload = factories["music.Upload"](
        library__privacy_level=privacy_level,
        import_status="finished",
    )
    queryset = models.Artist.objects.playable_by(None).annotate_playable_by_user(None)
    match = upload.track.artist in list(queryset)
    assert match is expected
    if expected:
        assert bool(queryset.first().is_playable_by_user) is expected


def test_upload_listen_url(factories):
    upload = factories["music.Upload"]()
    expected = upload.track.listen_url + f"?upload={upload.uuid}"

    assert upload.listen_url == expected


def test_upload_listen_url_no_download(factories):
    upload = factories["music.Upload"]()
    expected = upload.track.listen_url + f"?upload={upload.uuid}&download=false"

    assert upload.listen_url_no_download == expected


def test_library_schedule_scan(factories, now):
    library = factories["music.Library"](uploads_count=5)

    scan = library.schedule_scan(library.owner)

    assert scan.creation_date >= now
    assert scan.status == "pending"
    assert scan.library == library
    assert scan.submitted_by == library.owner
    assert scan.total_files == 5
    assert scan.processed_files == 0
    assert scan.errored_files == 0
    assert scan.modification_date is None


def test_library_schedule_scan_too_recent(factories, now):
    library = factories["music.Library"]()
    models.LibraryScan.objects.create(
        library=library, submitted_by=library.owner, status="finished"
    )
    result = library.schedule_scan(library.owner)

    assert result is None
    assert library.scans.count() == 1


def test_get_audio_data(factories):
    upload = factories["music.Upload"]()

    result = upload.get_audio_data()

    assert result == {"duration": 1, "bitrate": 112000, "size": 15918}


@pytest.mark.parametrize(
    "factory_args,expected",
    [
        ({"audio_file__filename": "test.mp3", "mimetype": None}, "mp3"),
        ({"mimetype": "audio/mpeg"}, "mp3"),
        ({"in_place": True, "source": "file:///test.mp3"}, "mp3"),
        ({"audio_file__filename": "test.None", "mimetype": "audio/mpeg"}, "mp3"),
        ({"audio_file__filename": "test.None", "mimetype": "audio/flac"}, "flac"),
        ({"audio_file__filename": "test.None", "mimetype": "audio/x-flac"}, "flac"),
    ],
)
def test_upload_extension(factory_args, factories, expected, settings):
    settings.MUSIC_DIRECTORY_PATH = "/"
    upload = factories["music.Upload"].build(**factory_args)

    assert upload.extension == expected


def test_can_create_license(db):
    models.License.objects.create(
        code="cc-by-sa",
        copyleft=True,
        commercial=True,
        attribution=True,
        derivative=True,
        redistribute=True,
        url="http://cc",
    )


def test_track_order_for_album(factories):
    album = factories["music.Album"]()
    t1 = factories["music.Track"](album=album, position=1, disc_number=1)
    t2 = factories["music.Track"](album=album, position=1, disc_number=2)
    t3 = factories["music.Track"](album=album, position=2, disc_number=1)
    t4 = factories["music.Track"](album=album, position=2, disc_number=2)

    assert list(models.Track.objects.order_for_album()) == [t1, t3, t2, t4]


@pytest.mark.parametrize(
    "initial, updated, expected",
    [
        ({"name": "hello"}, {"name": "world"}, False),
        ({"privacy_level": "instance"}, {"name": "world"}, False),
        ({"privacy_level": "instance"}, {"privacy_level": "me"}, True),
        ({"privacy_level": "instance"}, {"privacy_level": "instance"}, False),
    ],
)
def test_saving_library_sets_privacy_level_updated_flag(
    initial, updated, expected, factories
):
    library = factories["music.Library"](**initial)
    for key, value in updated.items():
        setattr(library, key, value)

    library.save()

    assert getattr(library, "_privacy_level_updated", False) is expected


@pytest.mark.parametrize("value, expected", [(True, True), (False, False)])
def test_saving_library_with_privacy_level_updated_flag(
    value, expected, factories, mocker
):
    library = factories["music.Library"]()
    create_entries = mocker.patch.object(models.TrackActor, "create_entries")
    setattr(library, "_privacy_level_updated", value)
    library.save()

    called = create_entries.call_count > 0
    assert called is expected
    if expected:
        create_entries.assert_called_once_with(library)


@pytest.mark.parametrize(
    "initial_privacy_level, updated_privacy_level, initial_playable_tracks, updated_playable_tracks",
    [
        (
            "me",
            "everyone",
            {"owner": [0], "subscriber": [0], "other_user": [], None: []},
            {"owner": [0], "subscriber": [0], "other_user": [0], None: [0]},
        ),
        (
            "me",
            "instance",
            {"owner": [0], "subscriber": [0], "other_user": [], None: []},
            {"owner": [0], "subscriber": [0], "other_user": [0], None: []},
        ),
        (
            "instance",
            "me",
            {"owner": [0], "subscriber": [0], "other_user": [0], None: []},
            {"owner": [0], "subscriber": [0], "other_user": [], None: []},
        ),
        (
            "instance",
            "everyone",
            {"owner": [0], "subscriber": [0], "other_user": [0], None: []},
            {"owner": [0], "subscriber": [0], "other_user": [0], None: [0]},
        ),
        (
            "everyone",
            "me",
            {"owner": [0], "subscriber": [0], "other_user": [0], None: [0]},
            {"owner": [0], "subscriber": [0], "other_user": [], None: []},
        ),
        (
            "everyone",
            "instance",
            {"owner": [0], "subscriber": [0], "other_user": [0], None: [0]},
            {"owner": [0], "subscriber": [0], "other_user": [0], None: []},
        ),
    ],
)
def test_update_library_privacy_level_create_entries(
    initial_privacy_level,
    updated_privacy_level,
    initial_playable_tracks,
    updated_playable_tracks,
    factories,
):
    users = {
        "owner": factories["users.User"](),
        "subscriber": factories["users.User"](),
        "other_user": factories["users.User"](),
        None: None,
    }
    library = factories["music.Library"](
        owner=users["owner"], privacy_level=initial_privacy_level
    )
    channel = factories["audio.Channel"](library=library, owner=users["owner"])
    factories["audio.Subscription"](
        channel=channel, user=users["subscriber"], approved=True
    )

    tracks = [
        factories["music.Upload"](playable=True, library=library).track,
        factories["music.Upload"](library=library, import_status="pending").track,
    ]

    for user_name, expected in initial_playable_tracks.items():
        user = users[user_name]
        expected_tracks = [tracks[i] for i in expected]
        assert list(models.Track.objects.playable_by(user)) == expected_tracks

    library.privacy_level = updated_privacy_level

    models.TrackActor.create_entries(library)

    for user_name, expected in updated_playable_tracks.items():
        user = users[user_name]
        expected_tracks = [tracks[i] for i in expected]
        assert list(models.Track.objects.playable_by(user)) == expected_tracks
