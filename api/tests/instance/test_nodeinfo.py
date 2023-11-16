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
            "actorId": "https://test.federation/federation/actors/service",
            "private": False,
            "shortDescription": "",
            "longDescription": "",
            "rules": "",
            "contactEmail": "",
            "terms": "",
            "nodeName": "",
            "banner": None,
            "defaultUploadQuota": 1000,
            "library": {
                "federationEnabled": True,
                "anonymousCanListen": False,
                "tracks": OrderedDict([("total", 0)]),
                "artists": OrderedDict([("total", 0)]),
                "albums": OrderedDict([("total", 0)]),
                "music": OrderedDict([("hours", 0)]),
            },
            "supportedUploadExtensions": SUPPORTED_EXTENSIONS,
            "allowList": {"enabled": False, "domains": None},
            "reportTypes": [
                OrderedDict(
                    [
                        ("type", "takedown_request"),
                        ("label", "Takedown request"),
                        ("anonymous", True),
                    ]
                ),
                OrderedDict(
                    [
                        ("type", "invalid_metadata"),
                        ("label", "Invalid metadata"),
                        ("anonymous", False),
                    ]
                ),
                OrderedDict(
                    [
                        ("type", "illegal_content"),
                        ("label", "Illegal content"),
                        ("anonymous", True),
                    ]
                ),
                OrderedDict(
                    [
                        ("type", "offensive_content"),
                        ("label", "Offensive content"),
                        ("anonymous", False),
                    ]
                ),
                OrderedDict(
                    [("type", "other"), ("label", "Other"), ("anonymous", False)]
                ),
            ],
            "funkwhaleSupportMessageEnabled": True,
            "instanceSupportMessage": "",
            "endpoints": OrderedDict(
                [("knownNodes", None), ("channels", None), ("libraries", None)]
            ),
            "usage": {
                "favorites": OrderedDict([("tracks", {"total": 0})]),
                "listenings": OrderedDict([("total", 0)]),
                "downloads": OrderedDict([("total", 0)]),
            },
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
        "usage": {
            "users": OrderedDict(
                [("total", 0), ("activeHalfyear", 0), ("activeMonth", 0)]
            ),
            "localPosts": 0,
            "localComments": 0,
        },
        "metadata": {
            "actorId": "https://test.federation/federation/actors/service",
            "private": False,
            "shortDescription": "",
            "longDescription": "",
            "contactEmail": "",
            "nodeName": "",
            "banner": None,
            "defaultUploadQuota": 1000,
            "supportedUploadExtensions": SUPPORTED_EXTENSIONS,
            "allowList": {"enabled": False, "domains": None},
            "funkwhaleSupportMessageEnabled": True,
            "instanceSupportMessage": "",
            "usage": OrderedDict(
                [
                    ("favorites", OrderedDict([("tracks", {"total": 0})])),
                    ("listenings", OrderedDict([("total", 0)])),
                    ("downloads", OrderedDict([("total", 0)])),
                ]
            ),
            "location": "",
            "languages": ["en"],
            "features": ["channels", "podcasts", "federation"],
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
        },
    }

    assert response.data == expected
