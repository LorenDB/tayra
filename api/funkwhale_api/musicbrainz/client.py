import musicbrainzngs
from cache_memoize import cache_memoize
from django.conf import settings

from funkwhale_api import __version__

_api = musicbrainzngs
_api.set_useragent("funkwhale", str(__version__), settings.FUNKWHALE_URL)
_api.set_hostname(settings.MUSICBRAINZ_HOSTNAME)


def clean_artist_search(query, **kwargs):
    cleaned_kwargs = {}
    if kwargs.get("name"):
        cleaned_kwargs["artist"] = kwargs.get("name")
    return _api.search_artists(query, **cleaned_kwargs)


class API(object):
    _api = _api

    class artists(object):
        search = cache_memoize(
            settings.MUSICBRAINZ_CACHE_DURATION,
            prefix="memoize:musicbrainz:clean_artist_search",
        )(clean_artist_search)
        get = cache_memoize(
            settings.MUSICBRAINZ_CACHE_DURATION,
            prefix="memoize:musicbrainz:get_artist_by_id",
        )(_api.get_artist_by_id)

    class images(object):
        get_front = cache_memoize(
            settings.MUSICBRAINZ_CACHE_DURATION,
            prefix="memoize:musicbrainz:get_image_front",
        )(_api.get_image_front)

    class recordings(object):
        search = cache_memoize(
            settings.MUSICBRAINZ_CACHE_DURATION,
            prefix="memoize:musicbrainz:search_recordings",
        )(_api.search_recordings)
        get = cache_memoize(
            settings.MUSICBRAINZ_CACHE_DURATION,
            prefix="memoize:musicbrainz:get_recording_by_id",
        )(_api.get_recording_by_id)

    class releases(object):
        search = cache_memoize(
            settings.MUSICBRAINZ_CACHE_DURATION,
            prefix="memoize:musicbrainz:search_releases",
        )(_api.search_releases)
        get = cache_memoize(
            settings.MUSICBRAINZ_CACHE_DURATION,
            prefix="memoize:musicbrainz:get_release_by_id",
        )(_api.get_release_by_id)
        browse = cache_memoize(
            settings.MUSICBRAINZ_CACHE_DURATION,
            prefix="memoize:musicbrainz:browse_releases",
        )(_api.browse_releases)
        # get_image_front = _api.get_image_front

    class release_groups(object):
        search = cache_memoize(
            settings.MUSICBRAINZ_CACHE_DURATION,
            prefix="memoize:musicbrainz:search_release_groups",
        )(_api.search_release_groups)
        get = cache_memoize(
            settings.MUSICBRAINZ_CACHE_DURATION,
            prefix="memoize:musicbrainz:get_release_group_by_id",
        )(_api.get_release_group_by_id)
        browse = cache_memoize(
            settings.MUSICBRAINZ_CACHE_DURATION,
            prefix="memoize:musicbrainz:browse_release_groups",
        )(_api.browse_release_groups)
        # get_image_front = _api.get_image_front


api = API()
