import json
import logging
import pickle
import random

from django.core.cache import cache
from django.urls import reverse

from funkwhale_api.favorites.models import TrackFavorite
from funkwhale_api.radios import models, radios_v2


def test_can_get_track_for_session_from_api_v2(factories, logged_in_api_client):
    actor = logged_in_api_client.user.create_actor()
    track = factories["music.Upload"](
        library__actor=actor, import_status="finished"
    ).track
    url = reverse("api:v2:radios:sessions-list")
    response = logged_in_api_client.post(url, {"radio_type": "random"})
    session = models.RadioSession.objects.latest("id")

    url = reverse("api:v2:radios:sessions-tracks", kwargs={"pk": session.pk})
    response = logged_in_api_client.get(url, {"session": session.pk})
    data = json.loads(response.content.decode("utf-8"))

    assert data[0]["id"] == track.pk

    next_track = factories["music.Upload"](
        library__actor=actor, import_status="finished"
    ).track
    response = logged_in_api_client.get(url, {"session": session.pk})
    data = json.loads(response.content.decode("utf-8"))

    assert data[0]["id"] == next_track.id


def test_can_use_radio_session_to_filter_choices_v2(factories):
    factories["music.Upload"].create_batch(10)
    user = factories["users.User"]()
    radio = radios_v2.RandomRadio()
    session = radio.start_session(user)

    radio.pick_many(quantity=10, filter_playable=False)

    # ensure 10 different tracks have been suggested
    tracks_id = [
        session_track.track.pk for session_track in session.session_tracks.all()
    ]
    assert len(set(tracks_id)) == 10


def test_session_radio_excludes_previous_picks_v2(factories, logged_in_api_client):
    tracks = factories["music.Track"].create_batch(5)
    url = reverse("api:v2:radios:sessions-list")
    response = logged_in_api_client.post(url, {"radio_type": "random"})
    session = models.RadioSession.objects.latest("id")
    url = reverse("api:v2:radios:sessions-tracks", kwargs={"pk": session.pk})

    previous_choices = []

    for i in range(5):
        response = logged_in_api_client.get(
            url, {"session": session.pk, "filter_playable": False}
        )
        pick = json.loads(response.content.decode("utf-8"))
        assert pick[0]["title"] not in previous_choices
        assert pick[0]["title"] in [t.title for t in tracks]
        previous_choices.append(pick[0]["title"])

    response = logged_in_api_client.get(url, {"session": session.pk})
    assert (
        json.loads(response.content.decode("utf-8"))
        == "Radio doesn't have more candidates"
    )


def test_can_get_choices_for_favorites_radio_v2(factories):
    files = factories["music.Upload"].create_batch(10)
    tracks = [f.track for f in files]
    user = factories["users.User"]()
    for i in range(5):
        TrackFavorite.add(track=random.choice(tracks), user=user)

    radio = radios_v2.FavoritesRadio()
    session = radio.start_session(user=user)
    choices = session.radio(api_version=2).get_choices(
        quantity=100, filter_playable=False
    )

    assert len(choices) == user.track_favorites.all().count()

    for favorite in user.track_favorites.all():
        assert favorite.track in choices


def test_can_get_choices_for_custom_radio_v2(factories):
    artist = factories["music.Artist"]()
    files = factories["music.Upload"].create_batch(5, track__artist=artist)
    tracks = [f.track for f in files]
    factories["music.Upload"].create_batch(5)

    session = factories["radios.CustomRadioSession"](
        custom_radio__config=[{"type": "artist", "ids": [artist.pk]}]
    )
    choices = session.radio(api_version=2).get_choices(
        quantity=1, filter_playable=False
    )

    expected = [t.pk for t in tracks]
    for t in choices:
        assert t.id in expected


def test_can_cache_radio_track(factories):
    uploads = factories["music.Track"].create_batch(10)
    user = factories["users.User"]()
    radio = radios_v2.RandomRadio()
    session = radio.start_session(user)
    picked = session.radio(api_version=2).pick_many(quantity=1, filter_playable=False)
    assert len(picked) == 1
    for t in pickle.loads(cache.get(f"radiotracks{session.id}")):
        assert t in uploads


def test_regenerate_cache_if_not_enought_tracks_in_it(
    factories, caplog, logged_in_api_client
):
    logger = logging.getLogger("funkwhale_api.radios.radios_v2")
    caplog.set_level(logging.INFO)
    logger.addHandler(caplog.handler)

    factories["music.Track"].create_batch(10)
    factories["users.User"]()
    url = reverse("api:v2:radios:sessions-list")
    response = logged_in_api_client.post(url, {"radio_type": "random"})
    session = models.RadioSession.objects.latest("id")
    url = reverse("api:v2:radios:sessions-tracks", kwargs={"pk": session.pk})
    logged_in_api_client.get(url, {"count": 9, "filter_playable": False})
    response = logged_in_api_client.get(url, {"count": 10, "filter_playable": False})
    pick = json.loads(response.content.decode("utf-8"))
    assert (
        "Not enough radio tracks in cache. Trying to generate new cache" in caplog.text
    )
    assert len(pick) == 1
