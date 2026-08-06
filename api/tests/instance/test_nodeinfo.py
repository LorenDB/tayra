from collections import OrderedDict

from django.urls import reverse

from funkwhale_api import __version__ as api_version
from funkwhale_api.music.utils import SUPPORTED_EXTENSIONS


def test_nodeinfo_20(api_client):
    url = reverse("api:v1:instance:nodeinfo-2.0")
    response = api_client.get(url)

    expected = {
        "version": "2.0",
        "software": OrderedDict([("name", "funkwhale"), ("version", api_version)]),
        "protocols": ["activitypub"],
        "services": OrderedDict([("inbound", ["atom1.0"]), ("outbound", ["atom1.0"])]),
        "openRegistrations": False,
        "usage": {
            "users": OrderedDict(
                [("total", 0), ("activeHalfyear", 0), ("activeMonth", 0)]
            )
        },
        "metadata": {
            "private": False,
            "shortDescription": "",
            "longDescription": "",
            "contactEmail": "",
            "nodeName": "",
            "banner": None,
            "defaultUploadQuota": 1000,
            "supportedUploadExtensions": SUPPORTED_EXTENSIONS,
            "allowList": {"enabled": None, "domains": None},
            "usage": {
                "favorites": OrderedDict([("tracks", {"total": 0})]),
                "listenings": OrderedDict([("total", 0)]),
                "downloads": OrderedDict([("total", 0)]),
            },
            "library": {
                "anonymousCanListen": False,
                "tracks": OrderedDict([("total", 0)]),
                "artists": OrderedDict([("total", 0)]),
                "albums": OrderedDict([("total", 0)]),
                "music": OrderedDict([("hours", 0)]),
            },
            "endpoints": OrderedDict([("channels", None), ("libraries", None)]),
            "rules": "",
            "terms": "",
        },
    }

    assert response.data == expected


def test_nodeinfo_21(api_client):
    url = reverse("api:v2:instance:nodeinfo-2.1")
    response = api_client.get(url)

    expected = {
        "version": "2.1",
        "software": OrderedDict(
            [
                ("name", "funkwhale"),
                ("version", api_version),
                ("repository", "https://dev.funkwhale.audio/funkwhale/funkwhale"),
                ("homepage", "https://funkwhale.audio"),
            ]
        ),
        "protocols": ["activitypub"],
        "services": OrderedDict([("inbound", ["atom1.0"]), ("outbound", ["atom1.0"])]),
        "openRegistrations": False,
        "usage": OrderedDict(
            [
                (
                    "users",
                    OrderedDict(
                        [("total", 0), ("activeHalfyear", 0), ("activeMonth", 0)]
                    ),
                ),
                ("localPosts", 0),
                ("localComments", 0),
            ]
        ),
        "metadata": {
            "private": False,
            "shortDescription": "",
            "longDescription": "",
            "contactEmail": "",
            "nodeName": "",
            "banner": None,
            "defaultUploadQuota": 1000,
            "supportedUploadExtensions": SUPPORTED_EXTENSIONS,
            "allowList": {"enabled": None, "domains": None},
            "usage": OrderedDict(
                [
                    ("favorites", OrderedDict([("tracks", {"total": 0})])),
                    ("listenings", OrderedDict([("total", 0)])),
                    ("downloads", OrderedDict([("total", 0)])),
                ]
            ),
            "location": "",
            "content": OrderedDict(
                [
                    (
                        "local",
                        OrderedDict(
                            [
                                ("artists", 0),
                                ("releases", 0),
                                ("recordings", 0),
                                ("hoursOfContent", 0),
                            ]
                        ),
                    ),
                    ("topMusicCategories", []),
                    ("topPodcastCategories", []),
                ]
            ),
            "features": ["channels", "podcasts", "client_data", "rich_listenings"],
            "codeOfConduct": "",
        },
    }

    assert response.data == expected
