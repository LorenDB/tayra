import datetime

from django.db.models import Count, F, Sum
from django.utils import timezone

from funkwhale_api.favorites.models import TrackFavorite
from funkwhale_api.history.models import Listening
from funkwhale_api.music import models
from funkwhale_api.users.models import User


def get():
    return {
        "users": get_users(),
        "tracks": get_tracks(),
        "albums": get_albums(),
        "artists": get_artists(),
        "track_favorites": get_track_favorites(),
        "listenings": get_listenings(),
        "downloads": get_downloads(),
        "music_duration": get_music_duration(),
    }


def get_content():
    return {
        "local": {
            "artists": get_artists(),
            "releases": get_albums(),
            "recordings": get_tracks(),
            "hoursOfContent": get_music_duration(),
        },
        "topMusicCategories": get_top_music_categories(),
        "topPodcastCategories": get_top_podcast_categories(),
    }


def get_top_music_categories():
    return (
        models.Track.objects.filter(artist__content_category="music")
        .exclude(tagged_items__tag_id=None)
        .values(name=F("tagged_items__tag__name"))
        .annotate(count=Count("name"))
        .order_by("-count")[:3]
    )


def get_top_podcast_categories():
    return (
        models.Track.objects.filter(artist__content_category="podcast")
        .exclude(tagged_items__tag_id=None)
        .values(name=F("tagged_items__tag__name"))
        .annotate(count=Count("name"))
        .order_by("-count")[:3]
    )


def get_users():
    qs = User.objects.filter(is_active=True)
    now = timezone.now()
    active_month = now - datetime.timedelta(days=30)
    active_halfyear = now - datetime.timedelta(days=30 * 6)
    return {
        "total": qs.count(),
        "active_month": qs.filter(last_activity__gte=active_month).count(),
        "active_halfyear": qs.filter(last_activity__gte=active_halfyear).count(),
    }
    return User.objects.count()


def get_listenings():
    return Listening.objects.count()


def get_track_favorites():
    return TrackFavorite.objects.count()


def get_tracks():
    return models.Track.objects.local().count()


def get_albums():
    return models.Album.objects.local().count()


def get_artists():
    return models.Artist.objects.local().count()


def get_downloads():
    return models.Track.objects.aggregate(d=Sum("downloads_count"))["d"] or 0


def get_music_duration():
    seconds = models.Upload.objects.aggregate(d=Sum("duration"))["d"]
    if seconds:
        return seconds / 3600
    return 0
