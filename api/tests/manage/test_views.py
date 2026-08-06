from django.urls import reverse

from funkwhale_api.manage import serializers


def test_user_view(factories, superuser_api_client, mocker):
    mocker.patch("funkwhale_api.users.models.User.record_activity")
    users = factories["users.User"].create_batch(size=5) + [superuser_api_client.user]
    qs = users[0].__class__.objects.order_by("-id")
    url = reverse("api:v1:manage:users:users-list")

    response = superuser_api_client.get(url, {"sort": "-id"})
    expected = serializers.ManageUserSerializer(
        qs, many=True, context={"request": response.wsgi_request}
    ).data

    assert response.data["count"] == len(users)
    assert response.data["results"] == expected


def test_user_delete(factories, superuser_api_client, mocker):
    user = factories["users.User"]()
    delete = mocker.patch("funkwhale_api.users.tasks.delete_account.delay")
    url = reverse("api:v1:manage:users:users-detail", kwargs={"pk": user.pk})

    response = superuser_api_client.delete(url)

    assert response.status_code == 204
    user.refresh_from_db()
    assert user.is_active is False
    delete.assert_called_once_with(user_id=user.pk)


def test_user_delete_cannot_delete_self(superuser_api_client, mocker):
    delete = mocker.patch("funkwhale_api.users.tasks.delete_account.delay")
    url = reverse(
        "api:v1:manage:users:users-detail",
        kwargs={"pk": superuser_api_client.user.pk},
    )

    response = superuser_api_client.delete(url)

    assert response.status_code == 400
    delete.assert_not_called()
    superuser_api_client.user.refresh_from_db()
    assert superuser_api_client.user.is_active is True


def test_invitation_view(factories, superuser_api_client, mocker):
    invitations = factories["users.Invitation"].create_batch(size=5)
    qs = invitations[0].__class__.objects.order_by("-id")
    url = reverse("api:v1:manage:users:invitations-list")

    response = superuser_api_client.get(url, {"sort": "-id"})
    expected = serializers.ManageInvitationSerializer(qs, many=True).data

    assert response.data["count"] == len(invitations)
    assert response.data["results"] == expected


def test_invitation_view_create(factories, superuser_api_client, mocker):
    url = reverse("api:v1:manage:users:invitations-list")
    response = superuser_api_client.post(url)

    assert response.status_code == 201
    assert superuser_api_client.user.invitations.latest("id") is not None


def test_artist_list(factories, superuser_api_client, settings):
    artist = factories["music.Artist"]()
    url = reverse("api:v1:manage:library:artists-list")
    response = superuser_api_client.get(url)

    assert response.status_code == 200

    assert response.data["count"] == 1
    assert response.data["results"][0]["id"] == artist.id


def test_artist_detail(factories, superuser_api_client):
    artist = factories["music.Artist"]()
    url = reverse("api:v1:manage:library:artists-detail", kwargs={"pk": artist.pk})
    response = superuser_api_client.get(url)

    assert response.status_code == 200
    assert response.data["id"] == artist.id


def test_artist_detail_stats(factories, superuser_api_client):
    artist = factories["music.Artist"]()
    url = reverse("api:v1:manage:library:artists-stats", kwargs={"pk": artist.pk})
    response = superuser_api_client.get(url)
    expected = {
        "libraries": 0,
        "channels": 0,
        "uploads": 0,
        "listenings": 0,
        "playlists": 0,
        "mutations": 0,
        "track_favorites": 0,
        "media_total_size": 0,
        "media_downloaded_size": 0,
    }
    assert response.status_code == 200
    assert response.data == expected


def test_artist_delete(factories, superuser_api_client):
    artist = factories["music.Artist"]()
    url = reverse("api:v1:manage:library:artists-detail", kwargs={"pk": artist.pk})
    response = superuser_api_client.delete(url)

    assert response.status_code == 204


def test_album_list(factories, superuser_api_client, settings):
    album = factories["music.Album"]()
    factories["music.Album"]()
    url = reverse("api:v1:manage:library:albums-list")
    response = superuser_api_client.get(url, {"q": f'artist:"{album.artist.name}"'})

    assert response.status_code == 200

    assert response.data["count"] == 1
    assert response.data["results"][0]["id"] == album.id


def test_album_detail(factories, superuser_api_client):
    album = factories["music.Album"]()
    url = reverse("api:v1:manage:library:albums-detail", kwargs={"pk": album.pk})
    response = superuser_api_client.get(url)

    assert response.status_code == 200
    assert response.data["id"] == album.id


def test_album_detail_stats(factories, superuser_api_client):
    album = factories["music.Album"]()
    url = reverse("api:v1:manage:library:albums-stats", kwargs={"pk": album.pk})
    response = superuser_api_client.get(url)
    expected = {
        "libraries": 0,
        "channels": 0,
        "uploads": 0,
        "listenings": 0,
        "playlists": 0,
        "mutations": 0,
        "track_favorites": 0,
        "media_total_size": 0,
        "media_downloaded_size": 0,
    }
    assert response.status_code == 200
    assert response.data == expected


def test_album_delete(factories, superuser_api_client):
    album = factories["music.Album"]()
    url = reverse("api:v1:manage:library:albums-detail", kwargs={"pk": album.pk})
    response = superuser_api_client.delete(url)

    assert response.status_code == 204


def test_track_list(factories, superuser_api_client, settings):
    track = factories["music.Track"]()
    url = reverse("api:v1:manage:library:tracks-list")
    response = superuser_api_client.get(url)

    assert response.status_code == 200

    assert response.data["count"] == 1
    assert response.data["results"][0]["id"] == track.id


def test_track_detail(factories, superuser_api_client):
    track = factories["music.Track"]()
    url = reverse("api:v1:manage:library:tracks-detail", kwargs={"pk": track.pk})
    response = superuser_api_client.get(url)

    assert response.status_code == 200
    assert response.data["id"] == track.id


def test_track_detail_stats(factories, superuser_api_client):
    track = factories["music.Track"]()
    url = reverse("api:v1:manage:library:tracks-stats", kwargs={"pk": track.pk})
    response = superuser_api_client.get(url)
    expected = {
        "libraries": 0,
        "channels": 0,
        "uploads": 0,
        "listenings": 0,
        "playlists": 0,
        "mutations": 0,
        "track_favorites": 0,
        "media_total_size": 0,
        "media_downloaded_size": 0,
    }
    assert response.status_code == 200
    assert response.data == expected


def test_track_delete(factories, superuser_api_client):
    track = factories["music.Track"]()
    url = reverse("api:v1:manage:library:tracks-detail", kwargs={"pk": track.pk})
    response = superuser_api_client.delete(url)

    assert response.status_code == 204


def test_library_list(factories, superuser_api_client, settings):
    library = factories["music.Library"]()
    url = reverse("api:v1:manage:library:libraries-list")
    response = superuser_api_client.get(url)

    assert response.status_code == 200

    assert response.data["count"] == 1
    assert response.data["results"][0]["id"] == library.id


def test_library_list_exclude_channel_libraries(
    factories, superuser_api_client, settings
):
    factories["audio.Channel"]()
    url = reverse("api:v1:manage:library:libraries-list")
    response = superuser_api_client.get(url)

    assert response.status_code == 200
    assert response.data["count"] == 0


def test_library_detail(factories, superuser_api_client):
    library = factories["music.Library"]()
    url = reverse(
        "api:v1:manage:library:libraries-detail", kwargs={"uuid": library.uuid}
    )
    response = superuser_api_client.get(url)

    assert response.status_code == 200
    assert response.data["id"] == library.id


def test_library_update(factories, superuser_api_client):
    library = factories["music.Library"](privacy_level="everyone")
    url = reverse(
        "api:v1:manage:library:libraries-detail", kwargs={"uuid": library.uuid}
    )
    response = superuser_api_client.patch(url, {"privacy_level": "me"})

    assert response.status_code == 200
    library.refresh_from_db()
    assert library.privacy_level == "me"


def test_library_detail_stats(factories, superuser_api_client):
    library = factories["music.Library"]()
    url = reverse(
        "api:v1:manage:library:libraries-stats", kwargs={"uuid": library.uuid}
    )
    response = superuser_api_client.get(url)
    expected = {
        "uploads": 0,
        "tracks": 0,
        "albums": 0,
        "artists": 0,
        "media_total_size": 0,
        "media_downloaded_size": 0,
    }
    assert response.status_code == 200
    assert response.data == expected


def test_library_delete(factories, superuser_api_client):
    library = factories["music.Library"]()
    url = reverse(
        "api:v1:manage:library:libraries-detail", kwargs={"uuid": library.uuid}
    )
    response = superuser_api_client.delete(url)

    assert response.status_code == 204


def test_upload_list(factories, superuser_api_client, settings):
    upload = factories["music.Upload"]()
    url = reverse("api:v1:manage:library:uploads-list")
    response = superuser_api_client.get(url)

    assert response.status_code == 200

    assert response.data["count"] == 1
    assert response.data["results"][0]["id"] == upload.id


def test_upload_detail(factories, superuser_api_client):
    upload = factories["music.Upload"]()
    url = reverse("api:v1:manage:library:uploads-detail", kwargs={"uuid": upload.uuid})
    response = superuser_api_client.get(url)

    assert response.status_code == 200
    assert response.data["id"] == upload.id


def test_upload_delete(factories, superuser_api_client):
    upload = factories["music.Upload"]()
    url = reverse("api:v1:manage:library:uploads-detail", kwargs={"uuid": upload.uuid})
    response = superuser_api_client.delete(url)

    assert response.status_code == 204


def test_tag_detail(factories, superuser_api_client):
    tag = factories["tags.Tag"]()
    url = reverse("api:v1:manage:tags-detail", kwargs={"name": tag.name})
    response = superuser_api_client.get(url)

    assert response.status_code == 200
    assert response.data["name"] == tag.name


def test_tag_list(factories, superuser_api_client, settings):
    tag = factories["tags.Tag"]()
    url = reverse("api:v1:manage:tags-list")
    response = superuser_api_client.get(url)

    assert response.status_code == 200

    assert response.data["count"] == 1
    assert response.data["results"][0]["name"] == tag.name


def test_tag_delete(factories, superuser_api_client):
    tag = factories["tags.Tag"]()
    url = reverse("api:v1:manage:tags-detail", kwargs={"name": tag.name})
    response = superuser_api_client.delete(url)

    assert response.status_code == 204


def test_tag_purge(factories, superuser_api_client):
    tag_with_items = factories["tags.Tag"]()
    track = factories["music.Track"]()
    track.tagged_items.create(tag=tag_with_items)
    factories["tags.Tag"]()

    url = reverse("api:v1:manage:tags-purge")
    response = superuser_api_client.post(url)

    assert response.status_code == 200
    assert response.data["action"] == "purge"
    assert response.data["count"] == 1


def test_channel_list(factories, superuser_api_client, settings):
    channel = factories["audio.Channel"]()
    url = reverse("api:v1:manage:channels-list")
    response = superuser_api_client.get(url)

    assert response.status_code == 200

    assert response.data["count"] == 1
    assert response.data["results"][0]["id"] == channel.id


def test_channel_detail(factories, superuser_api_client):
    channel = factories["audio.Channel"]()
    url = reverse("api:v1:manage:channels-detail", kwargs={"composite": channel.uuid})
    response = superuser_api_client.get(url)

    assert response.status_code == 200
    assert response.data["id"] == channel.id


def test_channel_delete(factories, superuser_api_client, mocker):
    channel = factories["audio.Channel"]()
    url = reverse("api:v1:manage:channels-detail", kwargs={"composite": channel.uuid})
    response = superuser_api_client.delete(url)

    assert response.status_code == 204


def test_channel_detail_stats(factories, superuser_api_client):
    channel = factories["audio.Channel"]()
    url = reverse("api:v1:manage:channels-stats", kwargs={"composite": channel.uuid})
    response = superuser_api_client.get(url)
    expected = {
        "uploads": 0,
        "playlists": 0,
        "listenings": 0,
        "mutations": 0,
        "track_favorites": 0,
        "follows": 0,
        "media_total_size": 0,
        "media_downloaded_size": 0,
    }
    assert response.status_code == 200
    assert response.data == expected
