import musicbrainzngs
from cache_memoize import cache_memoize
from django.conf import settings

from funkwhale_api import __version__

_api = musicbrainzngs
_api.set_useragent("funkwhale", str(__version__), settings.FUNKWHALE_URL)
_api.set_hostname(settings.MUSICBRAINZ_HOSTNAME)
# musicbrainzngs urlopen calls have no timeout of their own; a hung lookup
# would pin process_upload until Celery's hard kill, leaving the upload pending.
try:
    import musicbrainzngs.musicbrainz as _mb_mod

    _orig_urlopen = getattr(_mb_mod, "urlopen", None)
    if _orig_urlopen is not None:
        _timeout = getattr(settings, "EXTERNAL_REQUESTS_TIMEOUT", 10)

        def _urlopen_with_timeout(req, *args, **kwargs):
            kwargs.setdefault("timeout", _timeout)
            return _orig_urlopen(req, *args, **kwargs)

        _mb_mod.urlopen = _urlopen_with_timeout
except Exception:
    pass


def clean_artist_search(query, **kwargs):
    cleaned_kwargs = {}
    if kwargs.get("name"):
        cleaned_kwargs["artist"] = kwargs.get("name")
    return _api.search_artists(query, **cleaned_kwargs)


class API:
    _api = _api

    class artists:
        search = cache_memoize(
            settings.MUSICBRAINZ_CACHE_DURATION,
            prefix="memoize:musicbrainz:clean_artist_search",
        )(clean_artist_search)
        get = cache_memoize(
            settings.MUSICBRAINZ_CACHE_DURATION,
            prefix="memoize:musicbrainz:get_artist_by_id",
        )(_api.get_artist_by_id)

    class images:
        get_front = cache_memoize(
            settings.MUSICBRAINZ_CACHE_DURATION,
            prefix="memoize:musicbrainz:get_image_front",
        )(_api.get_image_front)

    class recordings:
        search = cache_memoize(
            settings.MUSICBRAINZ_CACHE_DURATION,
            prefix="memoize:musicbrainz:search_recordings",
        )(_api.search_recordings)
        get = cache_memoize(
            settings.MUSICBRAINZ_CACHE_DURATION,
            prefix="memoize:musicbrainz:get_recording_by_id",
        )(_api.get_recording_by_id)

    class releases:
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

    class release_groups:
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
