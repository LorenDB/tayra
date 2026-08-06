import datetime

import pytest
from django.urls import reverse
from django.utils import timezone

from funkwhale_api.shares import models


@pytest.mark.django_db
def test_create_album_share(logged_in_api_client, factories):
    album = factories["music.Album"]()
    url = reverse("api:v1:shares-list")
    response = logged_in_api_client.post(
        url,
        {"object_type": "album", "object_id": album.pk, "label": "friends"},
        format="json",
    )
    assert response.status_code == 201
    assert response.data["object_type"] == "album"
    assert response.data["object_id"] == album.pk
    assert response.data["token"]
    assert response.data["url"].endswith(f"/share/{response.data['token']}")
    assert response.data["label"] == "friends"
    assert response.data["expiration_date"] is None
    assert models.ShareLink.objects.filter(
        owner=logged_in_api_client.user, object_id=album.pk
    ).exists()


@pytest.mark.django_db
def test_create_album_share_with_expiry(logged_in_api_client, factories):
    album = factories["music.Album"]()
    url = reverse("api:v1:shares-list")
    response = logged_in_api_client.post(
        url,
        {"object_type": "album", "object_id": album.pk, "expires_in_days": 7},
        format="json",
    )
    assert response.status_code == 201
    assert response.data["expiration_date"] is not None
    link = models.ShareLink.objects.get(token=response.data["token"])
    assert link.expiration_date > timezone.now()
    assert link.expiration_date < timezone.now() + datetime.timedelta(days=8)


@pytest.mark.django_db
def test_create_playlist_share_as_owner(logged_in_api_client, factories):
    playlist = factories["playlists.Playlist"](user=logged_in_api_client.user)
    url = reverse("api:v1:shares-list")
    response = logged_in_api_client.post(
        url,
        {"object_type": "playlist", "object_id": playlist.pk},
        format="json",
    )
    assert response.status_code == 201
    assert response.data["object_type"] == "playlist"


@pytest.mark.django_db
def test_create_playlist_share_as_non_owner_forbidden(logged_in_api_client, factories):
    other = factories["users.User"]()
    playlist = factories["playlists.Playlist"](user=other, privacy_level="everyone")
    url = reverse("api:v1:shares-list")
    response = logged_in_api_client.post(
        url,
        {"object_type": "playlist", "object_id": playlist.pk},
        format="json",
    )
    assert response.status_code == 403


@pytest.mark.django_db
def test_create_share_missing_object_404(logged_in_api_client):
    url = reverse("api:v1:shares-list")
    response = logged_in_api_client.post(
        url,
        {"object_type": "album", "object_id": 999999},
        format="json",
    )
    assert response.status_code == 404


@pytest.mark.django_db
def test_list_own_shares_only(logged_in_api_client, factories):
    album = factories["music.Album"]()
    mine = factories["shares.ShareLink"](
        owner=logged_in_api_client.user,
        object_type="album",
        object_id=album.pk,
    )
    factories["shares.ShareLink"](
        object_type="album",
        object_id=album.pk,
    )
    url = reverse("api:v1:shares-list")
    response = logged_in_api_client.get(url)
    assert response.status_code == 200
    results = response.data["results"] if "results" in response.data else response.data
    tokens = {r["token"] for r in results}
    assert mine.token in tokens
    assert len(tokens) == 1


@pytest.mark.django_db
def test_list_filter_by_object(logged_in_api_client, factories):
    a1 = factories["music.Album"]()
    a2 = factories["music.Album"]()
    factories["shares.ShareLink"](
        owner=logged_in_api_client.user, object_type="album", object_id=a1.pk
    )
    factories["shares.ShareLink"](
        owner=logged_in_api_client.user, object_type="album", object_id=a2.pk
    )
    url = reverse("api:v1:shares-list")
    response = logged_in_api_client.get(
        url, {"object_type": "album", "object_id": a1.pk}
    )
    assert response.status_code == 200
    results = response.data["results"] if "results" in response.data else response.data
    assert len(results) == 1
    assert results[0]["object_id"] == a1.pk


@pytest.mark.django_db
def test_delete_share(logged_in_api_client, factories):
    album = factories["music.Album"]()
    link = factories["shares.ShareLink"](
        owner=logged_in_api_client.user,
        object_type="album",
        object_id=album.pk,
    )
    url = reverse("api:v1:shares-detail", kwargs={"uuid": link.uuid})
    response = logged_in_api_client.delete(url)
    assert response.status_code == 204
    assert not models.ShareLink.objects.filter(pk=link.pk).exists()


@pytest.mark.django_db
def test_delete_other_users_share_404(logged_in_api_client, factories):
    album = factories["music.Album"]()
    link = factories["shares.ShareLink"](object_type="album", object_id=album.pk)
    url = reverse("api:v1:shares-detail", kwargs={"uuid": link.uuid})
    response = logged_in_api_client.delete(url)
    assert response.status_code == 404


@pytest.mark.django_db
def test_anonymous_cannot_list_shares(api_client):
    url = reverse("api:v1:shares-list")
    response = api_client.get(url)
    assert response.status_code in (401, 403)


@pytest.mark.django_db
def test_public_resolve_album(api_client, factories, preferences):
    preferences["common__api_authentication_required"] = True
    user = factories["users.User"]()
    album = factories["music.Album"]()
    track = factories["music.Track"](album=album)
    factories["music.Upload"](
        track=track,
        playable=True,
        library__owner=user,
        library__privacy_level="me",
    )
    link = factories["shares.ShareLink"](
        owner=user, object_type="album", object_id=album.pk
    )
    url = reverse("api:v1:shares-public", kwargs={"token": link.token})
    response = api_client.get(url)
    assert response.status_code == 200
    assert response.data["object_type"] == "album"
    assert response.data["object_id"] == album.pk
    assert response.data["item"]["id"] == album.pk
    assert len(response.data["tracks"]) == 1
    assert response.data["tracks"][0]["id"] == track.pk
    assert response.data["tracks"][0]["listen_url"] == track.listen_url
    assert response.data["tracks"][0]["is_playable"] is True


@pytest.mark.django_db
def test_public_resolve_playlist(api_client, factories):
    user = factories["users.User"]()
    playlist = factories["playlists.Playlist"](user=user)
    track = factories["music.Track"]()
    factories["playlists.PlaylistTrack"](playlist=playlist, track=track, index=0)
    factories["music.Upload"](
        track=track,
        playable=True,
        library__owner=user,
        library__privacy_level="me",
    )
    link = factories["shares.ShareLink"](
        owner=user, object_type="playlist", object_id=playlist.pk
    )
    url = reverse("api:v1:shares-public", kwargs={"token": link.token})
    response = api_client.get(url)
    assert response.status_code == 200
    assert response.data["object_type"] == "playlist"
    assert len(response.data["tracks"]) == 1


@pytest.mark.django_db
def test_public_resolve_invalid_token_404(api_client):
    url = reverse("api:v1:shares-public", kwargs={"token": "not-a-real-token"})
    response = api_client.get(url)
    assert response.status_code == 404


@pytest.mark.django_db
def test_public_resolve_expired_404(api_client, factories):
    album = factories["music.Album"]()
    link = factories["shares.ShareLink"](
        object_type="album",
        object_id=album.pk,
        expiration_date=timezone.now() - datetime.timedelta(hours=1),
    )
    url = reverse("api:v1:shares-public", kwargs={"token": link.token})
    response = api_client.get(url)
    assert response.status_code == 404


@pytest.mark.django_db
def test_public_resolve_revoked_404(api_client, factories):
    album = factories["music.Album"]()
    link = factories["shares.ShareLink"](
        object_type="album",
        object_id=album.pk,
        revoked_at=timezone.now(),
    )
    url = reverse("api:v1:shares-public", kwargs={"token": link.token})
    response = api_client.get(url)
    assert response.status_code == 404


@pytest.mark.django_db
def test_stream_with_share_token_private_library(api_client, factories, preferences):
    preferences["common__api_authentication_required"] = True
    user = factories["users.User"]()
    album = factories["music.Album"]()
    track = factories["music.Track"](album=album)
    upload = factories["music.Upload"](
        track=track,
        import_status="finished",
        library__owner=user,
        library__privacy_level="me",
    )
    link = factories["shares.ShareLink"](
        owner=user, object_type="album", object_id=album.pk
    )
    url = reverse("api:v1:listen-detail", kwargs={"uuid": track.uuid})
    response = api_client.get(url, {"share": link.token, "download": "false"})
    assert response.status_code == 200

    # Without share token, anonymous must not access private library
    response2 = api_client.get(url, {"download": "false"})
    assert response2.status_code in (401, 403, 404)


@pytest.mark.django_db
def test_stream_share_track_not_in_share_404(api_client, factories, preferences):
    preferences["common__api_authentication_required"] = True
    user = factories["users.User"]()
    album = factories["music.Album"]()
    track_in = factories["music.Track"](album=album)
    track_out = factories["music.Track"]()
    factories["music.Upload"](
        track=track_in,
        import_status="finished",
        library__owner=user,
        library__privacy_level="me",
    )
    factories["music.Upload"](
        track=track_out,
        import_status="finished",
        library__owner=user,
        library__privacy_level="me",
    )
    link = factories["shares.ShareLink"](
        owner=user, object_type="album", object_id=album.pk
    )
    url = reverse("api:v1:listen-detail", kwargs={"uuid": track_out.uuid})
    response = api_client.get(url, {"share": link.token, "download": "false"})
    assert response.status_code == 404


@pytest.mark.django_db
def test_stream_after_delete_share_fails(api_client, factories, preferences):
    preferences["common__api_authentication_required"] = True
    user = factories["users.User"]()
    album = factories["music.Album"]()
    track = factories["music.Track"](album=album)
    factories["music.Upload"](
        track=track,
        import_status="finished",
        library__owner=user,
        library__privacy_level="me",
    )
    link = factories["shares.ShareLink"](
        owner=user, object_type="album", object_id=album.pk
    )
    token = link.token
    link.delete()
    url = reverse("api:v1:listen-detail", kwargs={"uuid": track.uuid})
    response = api_client.get(url, {"share": token, "download": "false"})
    assert response.status_code in (401, 403, 404)


@pytest.mark.django_db
def test_invalid_share_token_does_not_open_anonymous_access(
    api_client, factories, preferences
):
    """Invalid ?share= must fail closed, not grant anonymous library access."""
    preferences["common__api_authentication_required"] = False
    upload = factories["music.Upload"](playable=True)
    url = reverse("api:v1:listen-detail", kwargs={"uuid": upload.track.uuid})
    response = api_client.get(url, {"share": "bogus-token", "download": "false"})
    assert response.status_code in (401, 403)


@pytest.mark.django_db
def test_public_resolve_does_not_leak_unplayable_upload_uuids(api_client, factories):
    """
    Public track payloads must only expose uploads the share owner can play.

    A finished upload in someone else's private library must not appear as
    uploads[0] when the owner has no playable file for that track.
    """
    owner = factories["users.User"]()
    stranger = factories["users.User"]()
    album = factories["music.Album"]()
    track = factories["music.Track"](album=album)
    # Only stranger has a finished private upload — owner cannot play it.
    private_upload = factories["music.Upload"](
        track=track,
        import_status="finished",
        library__owner=stranger,
        library__privacy_level="me",
    )
    link = factories["shares.ShareLink"](
        owner=owner, object_type="album", object_id=album.pk
    )
    url = reverse("api:v1:shares-public", kwargs={"token": link.token})
    response = api_client.get(url)
    assert response.status_code == 200
    assert len(response.data["tracks"]) == 1
    track_data = response.data["tracks"][0]
    assert track_data["is_playable"] is False
    assert track_data["uploads"] == []
    # Ensure we did not leak the private upload UUID.
    blob = str(response.data)
    assert str(private_upload.uuid) not in blob


@pytest.mark.django_db
def test_inactive_owner_share_is_dead(api_client, factories, preferences):
    preferences["common__api_authentication_required"] = True
    user = factories["users.User"]()
    album = factories["music.Album"]()
    track = factories["music.Track"](album=album)
    factories["music.Upload"](
        track=track,
        import_status="finished",
        library__owner=user,
        library__privacy_level="me",
    )
    link = factories["shares.ShareLink"](
        owner=user, object_type="album", object_id=album.pk
    )
    user.is_active = False
    user.save(update_fields=["is_active"])

    pub = reverse("api:v1:shares-public", kwargs={"token": link.token})
    assert api_client.get(pub).status_code == 404

    stream = reverse("api:v1:listen-detail", kwargs={"uuid": track.uuid})
    assert api_client.get(
        stream, {"share": link.token, "download": "false"}
    ).status_code in (401, 403, 404)


@pytest.mark.django_db
def test_share_stream_forces_inline_not_attachment(api_client, factories, preferences):
    """Share holders listen only — download=true must not force attachment."""
    preferences["common__api_authentication_required"] = True
    user = factories["users.User"]()
    album = factories["music.Album"]()
    track = factories["music.Track"](album=album)
    factories["music.Upload"](
        track=track,
        import_status="finished",
        library__owner=user,
        library__privacy_level="me",
    )
    link = factories["shares.ShareLink"](
        owner=user, object_type="album", object_id=album.pk
    )
    url = reverse("api:v1:listen-detail", kwargs={"uuid": track.uuid})
    response = api_client.get(url, {"share": link.token, "download": "true"})
    assert response.status_code == 200
    # Attachment disposition should not be set for share streams.
    assert "attachment" not in (response.get("Content-Disposition") or "").lower()


@pytest.mark.django_db
def test_cannot_create_share_with_forged_owner(logged_in_api_client, factories):
    album = factories["music.Album"]()
    other = factories["users.User"]()
    url = reverse("api:v1:shares-list")
    response = logged_in_api_client.post(
        url,
        {
            "object_type": "album",
            "object_id": album.pk,
            "owner": other.pk,
            "token": "attacker-chosen-token-value-xxxxxxxx",
        },
        format="json",
    )
    assert response.status_code == 201
    from funkwhale_api.shares import models

    link = models.ShareLink.objects.get(token=response.data["token"])
    assert link.owner_id == logged_in_api_client.user.pk
    assert link.token != "attacker-chosen-token-value-xxxxxxxx"
    assert len(link.token) >= 32
