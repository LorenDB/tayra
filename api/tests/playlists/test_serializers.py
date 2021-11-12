from funkwhale_api.federation import serializers as federation_serializers
from funkwhale_api.playlists import serializers
from funkwhale_api.users import serializers as users_serializers


def test_playlist_serializer_include_covers(factories, api_request):
    playlist = factories["playlists.Playlist"]()
    t1 = factories["music.Track"](album__with_cover=True)
    t2 = factories["music.Track"](album__with_cover=True)
    t3 = factories["music.Track"](album__attachment_cover=None)
    t4 = factories["music.Track"](album__with_cover=True)
    t5 = factories["music.Track"](album__with_cover=True)
    t6 = factories["music.Track"](album__with_cover=True)
    t7 = factories["music.Track"](album__with_cover=True)

    playlist.insert_many([t1, t2, t3, t4, t5, t6, t7])
    request = api_request.get("/")
    qs = playlist.__class__.objects.with_covers().with_tracks_count()

    expected = [
        t1.album.attachment_cover.download_url_medium_square_crop,
        t2.album.attachment_cover.download_url_medium_square_crop,
        t4.album.attachment_cover.download_url_medium_square_crop,
        t5.album.attachment_cover.download_url_medium_square_crop,
        t6.album.attachment_cover.download_url_medium_square_crop,
    ]

    serializer = serializers.PlaylistSerializer(qs.get(), context={"request": request})
    assert serializer.data["album_covers"] == expected


def test_playlist_serializer_include_duration(tmpfile, factories):
    playlist = factories["playlists.Playlist"]()
    event = {
        "path": tmpfile.name,
    }
    library = factories["music.Library"]()
    track1 = factories["music.Track"]()
    track2 = factories["music.Track"]()
    factories["music.Upload"](
        source="file://{}".format(event["path"]),
        track=track1,
        checksum="old",
        library=library,
        import_status="finished",
        audio_file=None,
        duration=21,
    )
    factories["music.Upload"](
        source="file://{}".format(event["path"]),
        track=track1,
        checksum="old",
        library=library,
        import_status="finished",
        audio_file=None,
        duration=21,
    )
    factories["music.Upload"](
        source="file://{}".format(event["path"]),
        track=track2,
        checksum="old",
        library=library,
        import_status="finished",
        audio_file=None,
        duration=21,
    )
    playlist.insert_many([track1, track2])
    qs = playlist.__class__.objects.with_duration().with_tracks_count()

    serializer = serializers.PlaylistSerializer(qs.get())
    assert serializer.data["duration"] == 42


def test_playlist_serializer(factories, to_api_date):
    playlist = factories["playlists.Playlist"]()
    actor = playlist.user.create_actor()

    expected = {
        "id": playlist.pk,
        "name": playlist.name,
        "privacy_level": playlist.privacy_level,
        "is_playable": None,
        "creation_date": to_api_date(playlist.creation_date),
        "modification_date": to_api_date(playlist.modification_date),
        "actor": federation_serializers.APIActorSerializer(actor).data,
        "user": users_serializers.UserBasicSerializer(playlist.user).data,
        "duration": 0,
        "tracks_count": 0,
        "album_covers": [],
    }
    serializer = serializers.PlaylistSerializer(playlist)

    assert serializer.data == expected
