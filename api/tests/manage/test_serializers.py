import pytest

from funkwhale_api.common import serializers as common_serializers
from funkwhale_api.manage import serializers


def test_manage_upload_action_delete(factories):
    uploads = factories["music.Upload"](size=5)
    s = serializers.ManageUploadActionSerializer(queryset=None)

    s.handle_delete(uploads.__class__.objects.all())

    assert uploads.__class__.objects.count() == 0


def test_user_update_permission(factories):
    user = factories["users.User"](
        permission_library=False,
        permission_moderation=False,
        permission_settings=True,
        is_active=True,
    )
    s = serializers.ManageUserSerializer(
        user,
        data={
            "is_active": False,
            "permissions": {"moderation": True, "settings": False},
            "upload_quota": 12,
        },
    )
    s.is_valid(raise_exception=True)
    s.save()
    user.refresh_from_db()

    assert user.is_active is False
    assert user.upload_quota == 12
    assert user.permission_moderation is True
    assert user.permission_library is False
    assert user.permission_settings is False


def test_manage_artist_serializer(factories, now, to_api_date):
    artist = factories["music.Artist"](with_cover=True)
    channel = factories["audio.Channel"](artist=artist)
    # put channel in cache
    artist.get_channel()
    setattr(artist, "_tracks_count", 12)
    setattr(artist, "_albums_count", 13)
    expected = {
        "id": artist.id,
        "mbid": artist.mbid,
        "name": artist.name,
        "creation_date": to_api_date(artist.creation_date),
        "is_local": True,
        "tracks_count": 12,
        "albums_count": 13,
        "tags": [],
        "cover": common_serializers.AttachmentSerializer(artist.attachment_cover).data,
        "channel": str(channel.uuid),
        "content_category": artist.content_category,
    }
    s = serializers.ManageArtistSerializer(artist)

    assert s.data == expected


def test_manage_nested_track_serializer(factories, now, to_api_date):
    track = factories["music.Track"]()
    expected = {
        "id": track.id,
        "mbid": track.mbid,
        "title": track.title,
        "creation_date": to_api_date(track.creation_date),
        "position": track.position,
        "disc_number": track.disc_number,
        "is_local": True,
        "copyright": track.copyright,
        "license": track.license,
    }
    s = serializers.ManageNestedTrackSerializer(track)

    assert s.data == expected


def test_manage_nested_album_serializer(factories, now, to_api_date):
    album = factories["music.Album"](with_cover=True)
    setattr(album, "tracks_count", 44)
    expected = {
        "id": album.id,
        "mbid": album.mbid,
        "title": album.title,
        "creation_date": to_api_date(album.creation_date),
        "release_date": album.release_date.isoformat(),
        "cover": common_serializers.AttachmentSerializer(album.attachment_cover).data,
        "is_local": True,
        "tracks_count": 44,
    }
    s = serializers.ManageNestedAlbumSerializer(album)

    assert s.data == expected


def test_manage_nested_artist_serializer(factories, now, to_api_date):
    artist = factories["music.Artist"]()
    expected = {
        "id": artist.id,
        "mbid": artist.mbid,
        "name": artist.name,
        "creation_date": to_api_date(artist.creation_date),
        "is_local": True,
    }
    s = serializers.ManageNestedArtistSerializer(artist)

    assert s.data == expected


def test_manage_album_serializer(factories, now, to_api_date):
    album = factories["music.Album"](with_cover=True)
    factories["music.Track"](album=album)
    setattr(album, "_tracks_count", 42)
    expected = {
        "id": album.id,
        "mbid": album.mbid,
        "title": album.title,
        "creation_date": to_api_date(album.creation_date),
        "release_date": album.release_date.isoformat(),
        "cover": common_serializers.AttachmentSerializer(album.attachment_cover).data,
        "is_local": True,
        "artist_credit": [
            serializers.ManageNestedArtistCreditSerializer(ac).data
            for ac in album.artist_credit.all()
        ],
        "tags": [],
        "tracks_count": 1,
    }
    s = serializers.ManageAlbumSerializer(album)

    assert s.data == expected


def test_manage_track_serializer(factories, now, to_api_date):
    track = factories["music.Track"](with_cover=True)
    setattr(track, "uploads_count", 44)
    expected = {
        "id": track.id,
        "mbid": track.mbid,
        "title": track.title,
        "disc_number": track.disc_number,
        "position": track.position,
        "copyright": track.copyright,
        "license": track.license,
        "creation_date": to_api_date(track.creation_date),
        "is_local": True,
        "artist_credit": [
            serializers.ManageNestedArtistCreditSerializer(ac).data
            for ac in track.artist_credit.all()
        ],
        "album": serializers.ManageTrackAlbumSerializer(track.album).data,
        "uploads_count": 44,
        "tags": [],
        "cover": common_serializers.AttachmentSerializer(track.attachment_cover).data,
    }
    s = serializers.ManageTrackSerializer(track)

    assert s.data == expected


def test_manage_library_serializer(factories, now, to_api_date):
    library = factories["music.Library"]()
    setattr(library, "_uploads_count", 44)
    expected = {
        "id": library.id,
        "uuid": str(library.uuid),
        "name": library.name,
        "description": library.description,
        "domain": "",
        "is_local": True,
        "creation_date": to_api_date(library.creation_date),
        "privacy_level": library.privacy_level,
        "uploads_count": 44,
        "followers_count": 0,
    }
    s = serializers.ManageLibrarySerializer(library)

    assert s.data == expected


def test_manage_upload_serializer(factories, now, to_api_date):
    upload = factories["music.Upload"]()

    expected = {
        "id": upload.id,
        "uuid": str(upload.uuid),
        "domain": "",
        "is_local": True,
        "audio_file": upload.audio_file.url,
        "listen_url": upload.listen_url,
        "source": upload.source,
        "filename": upload.filename,
        "mimetype": upload.mimetype,
        "duration": upload.duration,
        "bitrate": upload.bitrate,
        "size": upload.size,
        "creation_date": to_api_date(upload.creation_date),
        "modification_date": to_api_date(upload.modification_date),
        "accessed_date": None,
        "import_date": None,
        "metadata": upload.metadata,
        "import_status": upload.import_status,
        "import_metadata": upload.import_metadata,
        "import_reference": upload.import_reference,
        "import_details": upload.import_details,
        "track": serializers.ManageNestedTrackSerializer(upload.track).data,
        "library": serializers.ManageNestedLibrarySerializer(upload.library).data,
    }
    s = serializers.ManageUploadSerializer(upload)

    assert s.data == expected


@pytest.mark.parametrize(
    "factory, serializer_class",
    [
        ("music.Track", serializers.ManageTrackActionSerializer),
        ("music.Album", serializers.ManageAlbumActionSerializer),
        ("music.Artist", serializers.ManageArtistActionSerializer),
        ("music.Library", serializers.ManageLibraryActionSerializer),
        ("music.Upload", serializers.ManageUploadActionSerializer),
        ("tags.Tag", serializers.ManageTagActionSerializer),
    ],
)
def test_action_serializer_delete(factory, serializer_class, factories):
    objects = factories[factory].create_batch(size=5)
    s = serializer_class(queryset=None)

    s.handle_delete(objects[0].__class__.objects.all())

    assert objects[0].__class__.objects.count() == 0


def test_manage_tag_serializer(factories, to_api_date):
    tag = factories["tags.Tag"]()

    setattr(tag, "_tracks_count", 42)
    setattr(tag, "_albums_count", 54)
    setattr(tag, "_artists_count", 66)
    expected = {
        "id": tag.id,
        "name": tag.name,
        "creation_date": to_api_date(tag.creation_date),
        "tracks_count": 42,
        "albums_count": 54,
        "artists_count": 66,
    }
    s = serializers.ManageTagSerializer(tag)

    assert s.data == expected


def test_manage_channel_serializer(factories, now, to_api_date):
    channel = factories["audio.Channel"](external=True)
    channel.artist.get_channel()
    expected = {
        "id": channel.id,
        "uuid": str(channel.uuid),
        "creation_date": to_api_date(channel.creation_date),
        "artist": serializers.ManageArtistSerializer(channel.artist).data,
        "rss_url": channel.rss_url,
        "metadata": channel.metadata,
    }
    s = serializers.ManageChannelSerializer(channel)

    assert s.data == expected
