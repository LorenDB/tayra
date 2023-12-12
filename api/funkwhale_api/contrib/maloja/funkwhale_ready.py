import json

from config import plugins

from .funkwhale_startup import PLUGIN


class MalojaException(Exception):
    pass


@plugins.register_hook(plugins.LISTENING_CREATED, PLUGIN)
def submit_listen(listening, conf, **kwargs):
    server_url = conf["server_url"]
    api_key = conf["api_key"]
    if not server_url or not api_key:
        return

    logger = PLUGIN["logger"]
    logger.info("Submitting listening to Maloja at %s", server_url)
    payload = get_payload(listening, api_key, conf)
    logger.debug("Maloja payload: %r", payload)
    url = server_url.rstrip("/") + "/apis/mlj_1/newscrobble"
    session = plugins.get_session()
    response = session.post(url, json=payload)
    response.raise_for_status()
    details = json.loads(response.text)
    if details["status"] == "success":
        logger.info("Maloja listening submitted successfully")
    else:
        raise MalojaException(response.text)


def get_payload(listening, api_key, conf):
    track = listening.track

    # See https://github.com/krateng/maloja/blob/master/API.md
    payload = {
        "key": api_key,
        "artists": [track.artist.name],
        "title": track.title,
        "time": int(listening.creation_date.timestamp()),
        "nofix": bool(conf.get("nofix")),
    }

    if track.album:
        if track.album.title:
            payload["album"] = track.album.title
        if track.album.artist:
            payload["albumartists"] = [track.album.artist.name]

    upload = track.uploads.filter(duration__gte=0).first()
    if upload:
        payload["length"] = upload.duration

    return payload
