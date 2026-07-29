"""Year-in-review listening stats aggregation (owner/self only)."""

import datetime

from django.db.models import Count, F, IntegerField, Q, Sum, Value
from django.db.models.functions import Coalesce, ExtractMonth
from django.utils import timezone

from funkwhale_api.music.models import Album, Artist, Track, Upload

from . import models

_SECONDS_ZERO = Coalesce(
    F("duration_seconds"), Value(0), output_field=IntegerField()
)


def _cover_url(attachment):
    if attachment is None:
        return None
    return attachment.download_url_medium_square_crop


def _track_cover_url(track):
    attachment = track.attachment_cover
    if attachment is None and track.album_id and track.album is not None:
        attachment = track.album.attachment_cover
    return _cover_url(attachment)


def _int_or_zero(value):
    return int(value or 0)


def _year_bounds(year):
    """
    Half-open [start, end) range in the active timezone so
    (user, creation_date) btree indexes can be used (not EXTRACT(YEAR)).
    """
    start = timezone.make_aware(datetime.datetime(year, 1, 1))
    end = timezone.make_aware(datetime.datetime(year + 1, 1, 1))
    return start, end


def _track_duration_map(track_ids):
    """
    Best-effort duration per track from Upload metadata.

    Prefer finished uploads with non-null duration (lowest id wins).
    Fall back to any non-null duration if no finished upload exists.
    """
    if not track_ids:
        return {}

    result = {}
    finished = (
        Upload.objects.filter(
            track_id__in=track_ids,
            import_status="finished",
            duration__isnull=False,
        )
        .order_by("track_id", "id")
        .values_list("track_id", "duration")
    )
    for track_id, duration in finished:
        if track_id not in result:
            result[track_id] = duration

    missing = [tid for tid in track_ids if tid not in result]
    if missing:
        any_upload = (
            Upload.objects.filter(
                track_id__in=missing,
                duration__isnull=False,
            )
            .order_by("track_id", "id")
            .values_list("track_id", "duration")
        )
        for track_id, duration in any_upload:
            if track_id not in result:
                result[track_id] = duration
    return result


def _estimated_seconds(base, total_seconds):
    """
    SUM(COALESCE(duration_seconds, track_duration, 0)).

    Equivalent to total_seconds (nulls already 0) plus track length for each
    listening that has no recorded duration. Duration map is loaded once for
    distinct tracks with null duration (not a correlated subquery per row).
    """
    null_by_track = list(
        base.filter(duration_seconds__isnull=True)
        .values("track_id")
        .annotate(n=Count("id"))
    )
    if not null_by_track:
        return total_seconds

    dur_map = _track_duration_map([row["track_id"] for row in null_by_track])
    extra = sum(dur_map.get(row["track_id"], 0) * row["n"] for row in null_by_track)
    return total_seconds + extra


def compute_listening_stats(user, year, limit=10):
    """
    Aggregate year-in-review metrics for a single user.

    Only rich listenings are included (duration, device, or client_session set).
    Stock thin scrobbles are ignored.
    total_seconds uses SUM(COALESCE(duration_seconds, 0)).
    estimated_seconds uses COALESCE(duration_seconds, track_upload_duration, 0).
    """
    start, end = _year_bounds(year)
    # Only rich client rows — ignore stock thin scrobbles (null duration/device/session).
    base = models.Listening.objects.rich().filter(
        user=user,
        creation_date__gte=start,
        creation_date__lt=end,
    )

    totals = base.aggregate(
        total_listens=Count("id"),
        total_seconds=Sum(_SECONDS_ZERO),
        listens_with_duration=Count(
            "id", filter=Q(duration_seconds__isnull=False)
        ),
        unique_tracks=Count("track_id", distinct=True),
        unique_artists=Count("track__artist_id", distinct=True),
        unique_albums=Count("track__album_id", distinct=True),
    )
    total_seconds = _int_or_zero(totals["total_seconds"])
    estimated_seconds = _estimated_seconds(base, total_seconds)

    top_tracks = _top_tracks(base, limit)
    top_artists = _top_artists(base, limit)
    top_albums = _top_albums(base, limit)
    monthly = _monthly(base)
    by_device = _by_device(base)

    return {
        "year": year,
        "total_listens": _int_or_zero(totals["total_listens"]),
        "total_seconds": total_seconds,
        "listens_with_duration": _int_or_zero(totals["listens_with_duration"]),
        "estimated_seconds": estimated_seconds,
        "unique_tracks": _int_or_zero(totals["unique_tracks"]),
        "unique_artists": _int_or_zero(totals["unique_artists"]),
        "unique_albums": _int_or_zero(totals["unique_albums"]),
        "top_tracks": top_tracks,
        "top_artists": top_artists,
        "top_albums": top_albums,
        "monthly": monthly,
        "by_device": by_device,
    }


def _top_tracks(base, limit):
    rows = list(
        base.order_by()
        .values("track_id")
        .annotate(
            count=Count("id"),
            total_seconds=Sum(_SECONDS_ZERO),
        )
        .order_by("-count", "-total_seconds", "track_id")[:limit]
    )
    if not rows:
        return []

    tracks = {
        t.id: t
        for t in Track.objects.filter(id__in=[r["track_id"] for r in rows])
        .select_related("artist", "attachment_cover", "album__attachment_cover")
    }
    result = []
    for row in rows:
        track = tracks.get(row["track_id"])
        if track is None:
            continue
        result.append(
            {
                "track_id": track.id,
                "title": track.title,
                "artist_name": track.artist.name if track.artist_id else None,
                "cover_url": _track_cover_url(track),
                "count": row["count"],
                "total_seconds": _int_or_zero(row["total_seconds"]),
            }
        )
    return result


def _top_artists(base, limit):
    rows = list(
        base.order_by()
        .exclude(track__artist_id__isnull=True)
        .values("track__artist_id")
        .annotate(
            count=Count("id"),
            total_seconds=Sum(_SECONDS_ZERO),
        )
        .order_by("-count", "-total_seconds", "track__artist_id")[:limit]
    )
    if not rows:
        return []

    artists = {
        a.id: a
        for a in Artist.objects.filter(
            id__in=[r["track__artist_id"] for r in rows]
        ).select_related("attachment_cover")
    }
    result = []
    for row in rows:
        artist = artists.get(row["track__artist_id"])
        if artist is None:
            continue
        result.append(
            {
                "artist_id": artist.id,
                "name": artist.name,
                "cover_url": _cover_url(artist.attachment_cover),
                "count": row["count"],
                "total_seconds": _int_or_zero(row["total_seconds"]),
            }
        )
    return result


def _top_albums(base, limit):
    rows = list(
        base.order_by()
        .exclude(track__album_id__isnull=True)
        .values("track__album_id")
        .annotate(
            count=Count("id"),
            total_seconds=Sum(_SECONDS_ZERO),
        )
        .order_by("-count", "-total_seconds", "track__album_id")[:limit]
    )
    if not rows:
        return []

    albums = {
        a.id: a
        for a in Album.objects.filter(
            id__in=[r["track__album_id"] for r in rows]
        ).select_related("artist", "attachment_cover")
    }
    result = []
    for row in rows:
        album = albums.get(row["track__album_id"])
        if album is None:
            continue
        result.append(
            {
                "album_id": album.id,
                "title": album.title,
                "artist_name": album.artist.name if album.artist_id else None,
                "cover_url": _cover_url(album.attachment_cover),
                "count": row["count"],
                "total_seconds": _int_or_zero(row["total_seconds"]),
            }
        )
    return result


def _monthly(base):
    """Return all 12 months; months with no listens have count/seconds 0."""
    # Clear Meta.ordering (Listening defaults to -creation_date). Without this,
    # Django adds creation_date to GROUP BY via ORDER BY, so each timestamp
    # becomes its own group with count=1 and the month dict keeps only the last.
    rows = {
        r["month"]: r
        for r in base.order_by()
        .annotate(month=ExtractMonth("creation_date"))
        .values("month")
        .annotate(
            count=Count("id"),
            total_seconds=Sum(_SECONDS_ZERO),
        )
        if r["month"] is not None
    }
    return [
        {
            "month": month,
            "count": _int_or_zero(rows[month]["count"]) if month in rows else 0,
            "total_seconds": (
                _int_or_zero(rows[month]["total_seconds"]) if month in rows else 0
            ),
        }
        for month in range(1, 13)
    ]


def _by_device(base):
    rows = (
        base.order_by()
        .values("source_device__uuid", "source_device__name")
        .annotate(
            count=Count("id"),
            total_seconds=Sum(_SECONDS_ZERO),
        )
        # Tertiary uuid keeps order stable when count/seconds tie (nulls share one group).
        .order_by("-count", "-total_seconds", "source_device__uuid")
    )
    return [
        {
            "device_uuid": str(row["source_device__uuid"])
            if row["source_device__uuid"] is not None
            else None,
            "device_name": row["source_device__name"],
            "count": row["count"],
            "total_seconds": _int_or_zero(row["total_seconds"]),
        }
        for row in rows
    ]
