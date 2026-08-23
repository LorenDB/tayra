import collections
import datetime
import logging
import os

from django.conf import settings
from django.core.cache import cache
from django.db import transaction
from django.db.models import Q
from django.dispatch import receiver
from django.utils import timezone
from musicbrainzngs import ResponseError
from requests.exceptions import HTTPError

from celery.exceptions import SoftTimeLimitExceeded

from funkwhale_api import musicbrainz
from funkwhale_api.common import channels, preferences
from funkwhale_api.common import utils as common_utils
from funkwhale_api.music.management.commands import import_files
from funkwhale_api.tags import models as tags_models
from funkwhale_api.tags import tasks as tags_tasks
from funkwhale_api.taskapp import celery

from . import licenses, metadata, models, signals

logger = logging.getLogger(__name__)


def populate_album_cover(album, source=None, replace=False):
    if album.attachment_cover and not replace:
        return
    if source and source.startswith("file://"):
        # let's look for a cover in the same directory
        path = os.path.dirname(source.replace("file://", "", 1))
        logger.info("[Album %s] scanning covers from %s", album.pk, path)
        cover = get_cover_from_fs(path)
        return common_utils.attach_file(album, "attachment_cover", cover)
    if album.mbid:
        logger.info(
            "[Album %s] Fetching cover from musicbrainz release %s",
            album.pk,
            str(album.mbid),
        )
        try:
            image_data = musicbrainz.api.images.get_front(str(album.mbid))
        except ResponseError as exc:
            logger.warning(
                "[Album %s] cannot fetch cover from musicbrainz: %s", album.pk, str(exc)
            )
        else:
            return common_utils.attach_file(
                album,
                "attachment_cover",
                {"content": image_data, "mimetype": "image/jpeg"},
                fetch=True,
            )


IMAGE_TYPES = [("jpg", "image/jpeg"), ("jpeg", "image/jpeg"), ("png", "image/png")]
FOLDER_IMAGE_NAMES = ["cover", "folder"]


def get_cover_from_fs(dir_path):
    if os.path.exists(dir_path):
        for name in FOLDER_IMAGE_NAMES:
            for e, m in IMAGE_TYPES:
                cover_path = os.path.join(dir_path, f"{name}.{e}")
                if not os.path.exists(cover_path):
                    logger.debug("Cover %s does not exists", cover_path)
                    continue
                with open(cover_path, "rb") as c:
                    logger.info("Found cover at %s", cover_path)
                    return {"mimetype": m, "content": c.read()}


def getter(data, *keys, default=None):
    if not data:
        return default
    v = data
    for k in keys:
        try:
            v = v[k]
        except KeyError:
            return default

    return v


class UploadImportError(ValueError):
    def __init__(self, code):
        self.code = code
        super().__init__(code)


def fail_import(upload, error_code, detail=None, **fields):
    old_status = upload.import_status
    upload.import_status = "errored"
    upload.import_details = {"error_code": error_code, "detail": detail}
    upload.import_details.update(fields)
    upload.import_date = timezone.now()
    upload.save(update_fields=["import_details", "import_status", "import_date"])

    broadcast = getter(
        upload.import_metadata, "funkwhale", "config", "broadcast", default=True
    )
    if broadcast:
        signals.upload_import_status_updated.send(
            old_status=old_status,
            new_status=upload.import_status,
            upload=upload,
            sender=None,
        )


def _mark_pending_upload_failed(upload_id, error_code, detail):
    """Mark an upload errored if it is still pending (used from task failure)."""
    try:
        upload = models.Upload.objects.get(pk=upload_id, import_status="pending")
    except models.Upload.DoesNotExist:
        logger.info(
            "process_upload failure handler: upload %s is missing or no longer pending",
            upload_id,
        )
        return
    logger.error(
        "Marking upload %s as errored (%s): %s", upload_id, error_code, detail
    )
    fail_import(upload, error_code, detail=detail)


def _process_upload_on_failure(exc, task_id, args, kwargs, einfo):
    """Celery callback so hard time-limits / worker crashes don't leave pending uploads."""
    upload_id = kwargs.get("upload_id")
    if upload_id is None:
        logger.error(
            "music.process_upload failed without upload_id (task_id=%s): %s",
            task_id,
            exc,
        )
        return
    detail = f"{type(exc).__name__}: {exc}"
    logger.error(
        "music.process_upload failed (task_id=%s upload_id=%s): %s",
        task_id,
        upload_id,
        detail,
    )
    _mark_pending_upload_failed(upload_id, "unknown_error", detail)


@celery.app.task(
    name="music.process_upload",
    soft_time_limit=270,
    on_failure=_process_upload_on_failure,
)
@celery.require_instance(
    models.Upload.objects.filter(import_status="pending").select_related(
        "library__owner",
        "library__channel__artist",
    ),
    "upload",
)
def process_upload(upload, update_denormalization=True):
    """
    Main handler to process uploads submitted by user and create the corresponding
    metadata (tracks/artists/albums) in our DB.
    """
    try:
        _process_upload_impl(upload, update_denormalization=update_denormalization)
    except SoftTimeLimitExceeded:
        logger.error(
            "process_upload exceeded soft time limit for upload %s", upload.pk
        )
        if upload.import_status == "pending":
            fail_import(
                upload,
                "import_timeout",
                detail=(
                    "Import exceeded the server time limit before finishing. "
                    "The file was received; relaunch the import from library "
                    "admin if the track is missing."
                ),
            )
        raise
    except Exception as exc:
        logger.exception("process_upload failed for upload %s", upload.pk)
        try:
            upload.refresh_from_db(fields=["import_status"])
        except Exception:
            pass
        if getattr(upload, "import_status", None) == "pending":
            fail_import(upload, "unknown_error", detail=str(exc))
        raise


def _process_upload_impl(upload, update_denormalization=True):
    from . import serializers

    channel = upload.library.get_channel()
    # When upload is linked to a channel instead of a library
    # we willingly ignore the metadata embedded in the file itself
    # and rely on user metadata only
    use_file_metadata = channel is None

    import_metadata = upload.import_metadata or {}
    internal_config = {"funkwhale": import_metadata.get("funkwhale", {})}
    forced_values_serializer = serializers.ImportMetadataSerializer(
        data=import_metadata,
        context={"user": upload.library.owner, "channel": channel},
    )
    if forced_values_serializer.is_valid():
        forced_values = forced_values_serializer.validated_data
    else:
        forced_values = {}
        if not use_file_metadata:
            detail = forced_values_serializer.errors
            metadata_dump = import_metadata
            return fail_import(
                upload, "invalid_metadata", detail=detail, file_metadata=metadata_dump
            )

    if channel:
        # ensure the upload is associated with the channel artist
        forced_values["artist"] = upload.library.channel.artist

    old_status = upload.import_status
    additional_data = {"upload_source": upload.source}

    if use_file_metadata:
        audio_file = upload.get_audio_file()
        if audio_file is not None:
            try:
                audio_file.seek(0)
            except Exception:
                pass

        file_tags = None
        parse_error = None
        try:
            m = metadata.Metadata(audio_file)
        except ValueError as e:
            parse_error = str(e)
            logger.warning(
                "Could not parse embedded tags for upload %s (%s): %s",
                upload.pk,
                getattr(getattr(upload, "audio_file", None), "name", None),
                e,
            )
        else:
            try:
                serializer = metadata.TrackMetadataSerializer(data=m)
                serializer.is_valid()
            except Exception as e:
                fail_import(upload, "unknown_error", detail=str(e))
                raise
            if serializer.is_valid():
                file_tags = serializer.validated_data
            else:
                parse_error = serializer.errors
                metadata_dump = None
                try:
                    metadata_dump = m.all()
                except Exception as e:
                    logger.warn(
                        "Cannot dump metadata for file %s: %s", audio_file, str(e)
                    )
                # Prefer form/MusicBrainz metadata over a hard fail when tags
                # are incomplete but the client already sent title/mbid.
                if not (
                    forced_values.get("title")
                    or forced_values.get("mbid")
                    or getter(internal_config, "funkwhale", "track", "uuid")
                ):
                    return fail_import(
                        upload,
                        "invalid_metadata",
                        detail=parse_error,
                        file_metadata=metadata_dump,
                    )

        if file_tags is None and (
            forced_values.get("title")
            or forced_values.get("mbid")
            or getter(internal_config, "funkwhale", "track", "uuid")
        ):
            logger.info(
                "Using client import_metadata for upload %s after tag parse failure: %s",
                upload.pk,
                parse_error,
            )
            file_tags = {}
        if file_tags is None:
            return fail_import(
                upload,
                "invalid_metadata",
                detail=parse_error
                or "Could not read tags from this file. Tag it with MusicBrainz Picard "
                "or use MusicBrainz lookup before uploading.",
            )

        file_tags = _enrich_metadata_from_forced(file_tags, forced_values)

        check_mbid = preferences.get("music__only_allow_musicbrainz_tagged_files")
        if check_mbid and not (
            file_tags.get("mbid") or forced_values.get("mbid")
        ):
            return fail_import(
                upload,
                "missing_musicbrainz_id",
                detail=(
                    "Only content tagged with a MusicBrainz ID is permitted on this "
                    "pod. Tag your files with MusicBrainz Picard, or use the "
                    "MusicBrainz lookup in the upload form before uploading."
                ),
            )

        final_metadata = collections.ChainMap(
            additional_data, file_tags, internal_config
        )
    else:
        final_metadata = collections.ChainMap(
            additional_data,
            forced_values,
            internal_config,
        )
    try:
        track = get_track_from_import_metadata(
            final_metadata, attributed_to=upload.library.owner, **forced_values
        )
    except UploadImportError as e:
        return fail_import(upload, e.code)
    except SoftTimeLimitExceeded:
        raise
    except Exception as e:
        fail_import(upload, "unknown_error", detail=str(e))
        raise

    broadcast = getter(
        internal_config, "funkwhale", "config", "broadcast", default=True
    )

    # under some situations, we want to skip the import (
    # for instance if the user already owns the files)
    owned_duplicates = get_owned_duplicates(upload, track)
    upload.track = track

    if owned_duplicates:
        upload.import_status = "skipped"
        upload.import_details = {
            "code": "already_imported_in_owned_libraries",
            # In order to avoid exponential growth of the database, we only
            # reference the first known upload which gets duplicated
            "duplicates": owned_duplicates[0],
        }
        upload.import_date = timezone.now()
        upload.save(
            update_fields=["import_details", "import_status", "import_date", "track"]
        )
        if broadcast:
            signals.upload_import_status_updated.send(
                old_status=old_status,
                new_status=upload.import_status,
                upload=upload,
                sender=None,
            )
        return

    # all is good, let's finalize the import
    try:
        audio_data = upload.get_audio_data()
    except Exception as e:
        # Duration/bitrate are optional; never leave the import pending for this.
        logger.warning("get_audio_data failed for upload %s: %s", upload.pk, e)
        audio_data = None
    if audio_data:
        upload.duration = audio_data["duration"]
        upload.size = audio_data["size"]
        upload.bitrate = audio_data["bitrate"]
    upload.import_status = "finished"
    upload.import_date = timezone.now()
    upload.save(
        update_fields=[
            "track",
            "import_status",
            "import_date",
            "size",
            "duration",
            "bitrate",
        ]
    )
    if channel:
        common_utils.update_modification_date(channel.artist)

    if update_denormalization:
        try:
            models.TrackActor.create_entries(
                library=upload.library,
                upload_and_track_ids=[(upload.pk, upload.track_id)],
                delete_existing=False,
            )
        except Exception:
            logger.exception(
                "TrackActor.create_entries failed after import finished for upload %s",
                upload.pk,
            )

    # update album cover, if needed (must not block or revert a finished import)
    if track.album and not track.album.attachment_cover:
        try:
            populate_album_cover(
                track.album,
                source=final_metadata.get("upload_source"),
            )
        except Exception:
            logger.exception(
                "populate_album_cover failed after import finished for upload %s",
                upload.pk,
            )

    if broadcast:
        signals.upload_import_status_updated.send(
            old_status=old_status,
            new_status=upload.import_status,
            upload=upload,
            sender=None,
        )


def get_cover(obj, field):
    cover = obj.get(field)
    if cover:
        try:
            url = cover["url"]
        except KeyError:
            url = cover["href"]

        return {"mimetype": cover["mediaType"], "url": url}


def get_owned_duplicates(upload, track):
    """
    Ensure we skip duplicate tracks to avoid wasting user/instance storage
    """
    owned_libraries = upload.library.owner.libraries.all()
    return (
        models.Upload.objects.filter(
            track__isnull=False, library__in=owned_libraries, track=track
        )
        .exclude(pk=upload.pk)
        .values_list("uuid", flat=True)
        .order_by("creation_date")
    )


def _enrich_metadata_from_forced(file_tags, forced_values):
    """Fill gaps in parsed file tags from client-supplied import_metadata."""
    tags = dict(file_tags or {})
    if "title" not in tags and forced_values.get("title"):
        tags["title"] = forced_values["title"]
    if "mbid" not in tags and forced_values.get("mbid"):
        tags["mbid"] = forced_values["mbid"]
    if "position" not in tags and forced_values.get("position"):
        tags["position"] = forced_values["position"]
    if "disc_number" not in tags and forced_values.get("disc_number"):
        tags["disc_number"] = forced_values["disc_number"]
    if not tags.get("artists") and forced_values.get("artist_name"):
        tags["artists"] = [{"name": forced_values["artist_name"]}]

    album = tags.get("album")
    if not isinstance(album, dict):
        album = {}
    else:
        album = dict(album)
    if forced_values.get("album_title") and (
        not album.get("title") or album.get("title") == metadata.UNKNOWN_ALBUM
    ):
        album["title"] = forced_values["album_title"]
    if forced_values.get("album_mbid") and not album.get("mbid"):
        album["mbid"] = forced_values["album_mbid"]
    if album:
        tags["album"] = album
    return tags


def _album_mbid_compatible(album_mbid):
    """Match untagged albums, or the same release MBID — never a different one."""
    mbid_ok = Q(mbid__isnull=True)
    if album_mbid:
        mbid_ok |= Q(mbid=album_mbid)
    return mbid_ok


def _pick_library_album(candidates, album_mbid):
    """Choose a same-titled library album to attach a later upload to.

    Distinct release MBIDs stay separate. An untagged late track may join the
    single remaining candidate (typically the already-imported MBID release).
    """
    if not candidates:
        return None
    if album_mbid:
        candidates = [c for c in candidates if c.mbid is None or c.mbid == album_mbid]
        if not candidates:
            return None
        return sort_candidates(candidates, ["mbid"])[0]

    mbids = {c.mbid for c in candidates if c.mbid}
    if len(mbids) > 1:
        # Ambiguous: several tagged editions share the title.
        return None
    return sort_candidates(candidates, ["mbid"])[0]


def _find_existing_album(
    album_title, album_mbid, album_artists_credits, attributed_to=None
):
    """Reuse an album already in the library when MBIDs were not available."""
    if album_mbid:
        existing = models.Album.objects.filter(mbid=album_mbid)
        if existing:
            return sort_candidates(existing, ["mbid"])[0]

    if not album_title:
        return None

    # Prefer the uploader's own library so a later (possibly untagged) file
    # joins the album they already started, not a same-titled release elsewhere.
    if attributed_to is not None:
        existing = models.Album.objects.filter(
            title__iexact=album_title,
            tracks__uploads__library__owner=attributed_to,
        ).distinct()
        picked = _pick_library_album(list(existing), album_mbid)
        if picked:
            return picked

    # Same-titled albums that already have a *different* release MBID must
    # stay distinct. Untagged albums can still receive a later MBID-tagged
    # track (partial album, then missing tracks).
    if album_artists_credits:
        existing = models.Album.objects.filter(
            _album_mbid_compatible(album_mbid),
            title__iexact=album_title,
            artist_credit__in=album_artists_credits,
        ).distinct()
        picked = _pick_library_album(list(existing), album_mbid)
        if picked:
            return picked

    return None


def get_best_candidate_or_create(model, query, defaults, sort_fields):
    """
    Like queryset.get_or_create() but does not crash if multiple objects
    are returned on the get() call
    """
    candidates = model.objects.filter(query)
    if candidates:
        return sort_candidates(candidates, sort_fields)[0], False

    return model.objects.create(**defaults), True


def sort_candidates(candidates, important_fields):
    """
    Given a list of objects and a list of fields,
    will return a sorted list of those objects by score.

    Score is higher for objects that have a non-empty attribute
    that is also present in important fields::

        artist1 = Artist(mbid=None, fid=None)
        artist2 = Artist(mbid="something", fid=None)

        # artist2 has a mbid, so is sorted first
        assert sort_candidates([artist1, artist2], ['mbid'])[0] == artist2

    Only supports string fields.
    """

    # map each fields to its score, giving a higher score to first fields
    fields_scores = {f: i + 1 for i, f in enumerate(sorted(important_fields))}
    candidates_with_scores = []
    for candidate in candidates:
        current_score = 0
        for field, score in fields_scores.items():
            v = getattr(candidate, field, "")
            if v:
                current_score += score

        candidates_with_scores.append((candidate, current_score))

    return [c for c, s in reversed(sorted(candidates_with_scores, key=lambda v: v[1]))]


@transaction.atomic
def get_track_from_import_metadata(
    data, update_cover=False, attributed_to=None, **forced_values
):
    track = _get_track(data, attributed_to=attributed_to, **forced_values)
    if update_cover and track and not track.album.attachment_cover:
        populate_album_cover(track.album, source=data.get("upload_source"))
    return track


def truncate(v, length):
    if v is None:
        return v
    return v[:length]


def _artists_list_to_artist_credit_data(artists):
    """Bridge legacy `artists` metadata into artist_credit structure."""
    result = []
    for i, a in enumerate(artists or []):
        if not a:
            continue
        result.append(
            {
                "artist": a,
                "credit": a.get("name", ""),
                "joinphrase": ", " if i < len(artists) - 1 else "",
                "index": i,
            }
        )
    return result


def _get_track(data, attributed_to=None, query_mb=True, **forced_values):
    track_uuid = getter(data, "funkwhale", "track", "uuid")

    logger.debug(f"Getting track from import metadata: {data}")
    if track_uuid:
        try:
            track = models.Track.objects.get(uuid=track_uuid)
        except models.Track.DoesNotExist:
            raise UploadImportError(code="track_uuid_not_found")
        return track

    track_mbid = (
        forced_values["mbid"] if "mbid" in forced_values else data.get("mbid", None)
    )
    try:
        album_mbid = getter(data, "album", "mbid")
    except TypeError:
        album_mbid = None
    query = None
    if album_mbid and track_mbid:
        query = Q(mbid=track_mbid, album__mbid=album_mbid)

    if query:
        try:
            return sort_candidates(models.Track.objects.filter(query), ["mbid"])[0]
        except IndexError:
            pass

    # get / create artist_credit for track
    album_artists_credits = None
    track_mb_response = None
    artist_credit_data = getter(data, "artist_credit", default=[]) or []
    if not artist_credit_data:
        artist_credit_data = _artists_list_to_artist_credit_data(
            getter(data, "artists", default=[])
        )

    if "artist" in forced_values:
        artist = forced_values["artist"]
        query = Q(artist=artist)
        defaults = {
            "artist": artist,
            "joinphrase": "",
            "credit": artist.name,
            "index": 0,
        }
        track_artist_credit, created = get_best_candidate_or_create(
            models.ArtistCredit, query, defaults=defaults, sort_fields=["mbid"]
        )
        track_artists_credits = [track_artist_credit]
    else:
        mbid = query_mb and (data.get("musicbrainz_id", None) or data.get("mbid", None))
        try:
            (
                track_artists_credits,
                track_mb_response,
            ) = get_or_create_artists_credits_from_musicbrainz(
                "recording",
                mbid,
            )
        except (NoMbid, HTTPError):
            track_artists_credits = (
                get_or_create_artists_credits_from_artist_credit_metadata(
                    artist_credit_data,
                )
            )

    # get / create album
    album_mb_response = None
    if "album" in forced_values:
        album = forced_values["album"]
        album_artists_credits = track_artists_credits
    else:
        mbid = query_mb and (data.get("musicbrainz_albumid", None) or album_mbid)
        try:
            (
                album_artists_credits,
                album_mb_response,
            ) = get_or_create_artists_credits_from_musicbrainz(
                "release",
                mbid,
            )
        except (NoMbid, HTTPError):
            album_artists = getter(data, "album", "artist_credit", default=None)
            if not album_artists:
                album_artists = _artists_list_to_artist_credit_data(
                    getter(data, "album", "artists", default=None)
                    or getter(data, "artists", default=[])
                )
            if album_artists:
                album_artists_credits = (
                    get_or_create_artists_credits_from_artist_credit_metadata(
                        album_artists,
                    )
                )
            else:
                album_artists_credits = track_artists_credits

        if "album" in data:
            album_data = data["album"]
            album_title = album_data["title"]
            if not album_mbid:
                album_mbid = album_data.get("mbid")

            defaults = {
                "title": album_title,
                "mbid": album_mbid,
                "release_date": album_data.get("release_date"),
            }
            if album_data.get("fdate"):
                defaults["creation_date"] = album_data.get("fdate")

            album = _find_existing_album(
                album_title,
                album_mbid,
                album_artists_credits,
                attributed_to=attributed_to,
            )
            created = album is None
            if created:
                album = models.Album.objects.create(**defaults)
            elif album.mbid is None and album_mbid:
                album.mbid = album_mbid
                album.save(update_fields=["mbid"])
            album.artist_credit.set(album_artists_credits)
            if created:
                tags_models.add_tags(album, *album_data.get("tags", []))
                common_utils.attach_content(
                    album, "description", album_data.get("description")
                )
                common_utils.attach_file(
                    album, "attachment_cover", album_data.get("cover_data")
                )
        else:
            album = None

    # get / create track
    track_title = forced_values["title"] if "title" in forced_values else data["title"]
    position = (
        forced_values["position"]
        if "position" in forced_values
        else data.get("position", 1)
    )
    disc_number = (
        forced_values["disc_number"]
        if "disc_number" in forced_values
        else data.get("disc_number")
    )
    license = (
        forced_values["license"]
        if "license" in forced_values
        else licenses.match(data.get("license"), data.get("copyright"))
    )
    copyright = (
        forced_values["copyright"]
        if "copyright" in forced_values
        else data.get("copyright")
    )
    description = (
        {"text": forced_values["description"], "content_type": "text/markdown"}
        if "description" in forced_values
        else data.get("description")
    )
    cover_data = (
        forced_values["cover"] if "cover" in forced_values else data.get("cover_data")
    )

    query = Q(
        title__iexact=track_title,
        artist_credit__in=track_artists_credits,
        album=album,
        position=position,
        disc_number=disc_number,
    )
    # Recording MBIDs are reused across releases; never match a recording on
    # a different album or the missing track is skipped as a duplicate.
    if track_mbid:
        if album_mbid:
            query |= Q(mbid=track_mbid, album__mbid=album_mbid)
        elif album is not None:
            query |= Q(mbid=track_mbid, album=album)
        else:
            query |= Q(mbid=track_mbid, album__isnull=True)
    defaults = {
        "title": track_title,
        "album": album,
        "mbid": track_mbid,
        "position": position,
        "disc_number": disc_number,
        "license": license,
        "copyright": copyright,
    }
    if data.get("fdate"):
        defaults["creation_date"] = data.get("fdate")

    track, created = get_best_candidate_or_create(
        models.Track, query, defaults=defaults, sort_fields=["mbid"]
    )

    if album is not None and track.album_id is None:
        track.album = album
        track.save(update_fields=["album"])

    if created:
        tags = (
            forced_values["tags"] if "tags" in forced_values else data.get("tags", [])
        )
        tags_models.add_tags(track, *tags)
        common_utils.attach_content(track, "description", description)
        common_utils.attach_file(track, "attachment_cover", cover_data)

    track.artist_credit.set(track_artists_credits)
    return track


def get_or_create_artist_from_ac(ac_data, attributed_to=None, from_activity_id=None):
    # Accept either nested {"artist": {...}} or flat artist dict
    if "artist" in ac_data and isinstance(ac_data["artist"], dict):
        source = ac_data["artist"]
    elif "artist" in ac_data and hasattr(ac_data["artist"], "pk"):
        return ac_data["artist"]
    else:
        source = ac_data

    mbid = source.get("mbid", None)
    name = source.get("name", ac_data.get("credit", None))
    creation_date = source.get("fdate", timezone.now())
    description = source.get("description", None)
    tags = source.get("tags", [])
    cover = source.get("cover_data", None)

    if mbid:
        query = Q(mbid=mbid)
    else:
        query = Q(name__iexact=name)

    defaults = {
        "name": name,
        "mbid": mbid,
        "creation_date": creation_date,
    }
    if source.get("fdate"):
        defaults["creation_date"] = source.get("fdate")

    artist, created = get_best_candidate_or_create(
        models.Artist, query, defaults=defaults, sort_fields=["mbid"]
    )
    if created:
        tags_models.add_tags(artist, *tags)
        common_utils.attach_content(artist, "description", description)
        common_utils.attach_file(artist, "attachment_cover", cover)
    return artist


class NoMbid(Exception):
    pass


def get_or_create_artists_credits_from_musicbrainz(mb_obj_type, mbid):
    if not mbid:
        raise NoMbid

    try:
        if mb_obj_type == "release":
            mb_obj = musicbrainz.api.releases.get(
                mbid, includes=["artists", "url-rels"]
            )
        elif mb_obj_type == "recording":
            mb_obj = musicbrainz.api.recordings.get(
                mbid, includes=["artists", "url-rels"]
            )
        else:
            raise NoMbid
    except Exception as e:
        logger.warning(
            "Couldn't get Musicbrainz information for %s with %s mbid: %s",
            mb_obj_type,
            mbid,
            e,
        )
        raise HTTPError(f"MusicBrainz lookup failed: {e}") from e

    artists_credits = []
    acs = mb_obj.get("recording", mb_obj).get("artist-credit", [])
    for i, ac in enumerate(acs):
        if isinstance(ac, str):
            continue
        artist_name = ac["artist"]["name"]
        joinphrase = ac.get("joinphrase", "")
        credit = ac.get("name", ac.get("credit", artist_name))
        ac = dict(ac)
        ac["credit"] = credit
        ac_artist = dict(ac["artist"])
        ac_artist["mbid"] = ac_artist.get("id")
        ac["artist"] = ac_artist

        artist = get_or_create_artist_from_ac(ac)

        defaults = {
            "artist": artist,
            "joinphrase": joinphrase,
            "credit": credit,
            "index": i,
        }
        query = (
            Q(artist=artist.pk)
            & Q(joinphrase=joinphrase)
            & Q(credit=credit)
            & Q(index=i)
        )
        artist_credit, created = get_best_candidate_or_create(
            models.ArtistCredit, query, defaults=defaults, sort_fields=["mbid"]
        )
        artists_credits.append(artist_credit)
    return artists_credits, mb_obj


def get_or_create_artists_credits_from_artist_credit_metadata(
    artists_credits_data,
):
    artists_credits = []
    for i, ac in enumerate(artists_credits_data or []):
        artist = get_or_create_artist_from_ac(ac)
        index = ac.get("index", i)
        credit = ac.get("credit", artist.name)
        joinphrase = ac.get("joinphrase", "")
        defaults = {
            "artist": artist,
            "credit": credit,
            "joinphrase": joinphrase,
            "index": index,
        }
        query = (
            Q(artist=artist)
            & Q(credit=credit)
            & Q(joinphrase=joinphrase)
            & Q(index=index)
        )
        artist_credit, created = get_best_candidate_or_create(
            models.ArtistCredit,
            query,
            defaults=defaults,
            sort_fields=["artist", "credit", "joinphrase"],
        )
        artists_credits.append(artist_credit)
    return artists_credits


@receiver(signals.upload_import_status_updated)
def broadcast_import_status_update_to_owner(old_status, new_status, upload, **kwargs):
    user = upload.library.owner
    if not user:
        return

    from . import serializers

    group = f"user.{user.pk}.imports"
    channels.group_send(
        group,
        {
            "type": "event.send",
            "text": "",
            "data": {
                "type": "import.status_updated",
                "upload": serializers.UploadForOwnerSerializer(upload).data,
                "old_status": old_status,
                "new_status": new_status,
            },
        },
    )


@celery.app.task(name="music.clean_transcoding_cache")
def clean_transcoding_cache():
    """Delete stale ad-hoc UploadVersions.

    Duration 0 (default) disables cleanup entirely. Quality-ladder rungs
    (high/medium/low) are always retained so background pre-warm work is not
    thrown away.
    """
    from . import quality as quality_mod

    delay = preferences.get("music__transcoding_cache_duration")
    if delay is None or delay < 1:
        return  # cache clearing disabled
    limit = timezone.now() - datetime.timedelta(minutes=delay)
    candidates = models.UploadVersion.objects.filter(
        Q(accessed_date__lt=limit) | Q(accessed_date=None)
    ).order_by("id")

    # Never GC multi-quality ladder derivatives.
    delete_ids = []
    for version in candidates.iterator(chunk_size=200):
        if quality_mod.is_ladder_version(version):
            continue
        delete_ids.append(version.pk)

    if not delete_ids:
        return 0
    return models.UploadVersion.objects.filter(pk__in=delete_ids).delete()


@celery.app.task(
    name="music.ensure_transcoded_version",
    ignore_result=True,
    soft_time_limit=900,
    time_limit=960,
    queue="transcode",
)
def ensure_transcoded_version(upload_id, format, max_bitrate=None):
    """Create a progressive derivative for *upload_id* if missing (ffmpeg)."""
    from . import quality as quality_mod

    try:
        upload = models.Upload.objects.get(pk=upload_id)
    except models.Upload.DoesNotExist:
        logger.warning("ensure_transcoded_version: upload %s missing", upload_id)
        return

    if not format:
        return

    if not quality_mod.needs_transcode(upload, format, max_bitrate=max_bitrate):
        return

    existing = quality_mod.find_transcoded_version(
        upload, format, max_bitrate=max_bitrate
    )
    if existing:
        return existing.pk

    try:
        version = quality_mod.ensure_transcoded_version_sync(
            upload, format, max_bitrate=max_bitrate
        )
        logger.info(
            "Transcoded upload %s → %s @ %s (%s bytes)",
            upload_id,
            format,
            max_bitrate,
            getattr(version, "size", None),
        )
        return version.pk
    except Exception:
        logger.exception(
            "Failed to transcode upload %s to %s @ %s",
            upload_id,
            format,
            max_bitrate,
        )
        raise


@celery.app.task(
    name="music.prewarm_upload_qualities",
    ignore_result=True,
    queue="transcode",
)
def prewarm_upload_qualities(upload_id, tiers=None):
    """Enqueue quality-ladder rungs for faster first play."""
    from . import quality as quality_mod

    try:
        upload = models.Upload.objects.get(pk=upload_id)
    except models.Upload.DoesNotExist:
        return

    for tier in tiers or quality_mod.PREWARM_TIERS:
        fmt, bitrate = quality_mod.profile_for_quality(tier)
        if not fmt:
            continue
        if not quality_mod.needs_transcode(upload, fmt, max_bitrate=bitrate):
            continue
        if quality_mod.find_transcoded_version(upload, fmt, max_bitrate=bitrate):
            continue
        ensure_transcoded_version.delay(upload_id, fmt, bitrate)


def _upload_needs_quality_prewarm(upload, tiers=None):
    """True if any ladder tier is missing for *upload*."""
    from . import quality as quality_mod

    for tier in tiers or quality_mod.PREWARM_TIERS:
        fmt, bitrate = quality_mod.profile_for_quality(tier)
        if not fmt:
            continue
        if not quality_mod.needs_transcode(upload, fmt, max_bitrate=bitrate):
            continue
        if not quality_mod.find_transcoded_version(upload, fmt, max_bitrate=bitrate):
            return True
    return False


@celery.app.task(
    name="music.schedule_quality_prewarm",
    ignore_result=True,
    queue="transcode",
)
def schedule_quality_prewarm(max_enqueue=100):
    """Scan the library and enqueue missing quality-ladder encodes.

    Runs on Celery beat. Processes a bounded batch each tick so a large
    library is gradually covered without flooding the worker.
    """
    if not preferences.get("music__transcoding_enabled"):
        return 0
    if not preferences.get("music__auto_prewarm_qualities"):
        return 0

    # Finished (or skipped-but-playable) uploads that have a local source.
    qs = (
        models.Upload.objects.filter(import_status__in=["finished", "skipped"])
        .filter(
            Q(audio_file__isnull=False) & ~Q(audio_file="")
            | Q(source__startswith="file://")
        )
        .order_by("id")
        .only("id", "audio_file", "source", "mimetype", "bitrate")
    )

    enqueued = 0
    for upload in qs.iterator(chunk_size=100):
        if enqueued >= max_enqueue:
            break
        try:
            if not _upload_needs_quality_prewarm(upload):
                continue
            prewarm_upload_qualities.delay(upload.pk)
            enqueued += 1
        except Exception:
            logger.exception(
                "schedule_quality_prewarm: failed evaluating upload %s",
                upload.pk,
            )

    if enqueued:
        logger.info(
            "schedule_quality_prewarm: enqueued prewarm for %s upload(s)",
            enqueued,
        )
    return enqueued


@receiver(signals.upload_import_status_updated)
def prewarm_qualities_on_import(old_status, new_status, upload, **kwargs):
    """After a successful import, pre-warm the progressive quality ladder."""
    if new_status != "finished":
        return
    if not preferences.get("music__transcoding_enabled"):
        return
    if not preferences.get("music__auto_prewarm_qualities"):
        return
    try:
        prewarm_upload_qualities.delay(upload.pk)
    except Exception:
        logger.debug("Could not enqueue quality prewarm for upload %s", upload.pk)


@celery.app.task(name="music.albums_set_tags_from_tracks")
@transaction.atomic
def albums_set_tags_from_tracks(ids=None, dry_run=False):
    qs = models.Album.objects.filter(tagged_items__isnull=True).order_by("id")
    qs = qs.values_list("id", flat=True)
    if ids is not None:
        qs = qs.filter(pk__in=ids)
    data = tags_tasks.get_tags_from_foreign_key(
        ids=qs,
        foreign_key_model=models.Track,
        foreign_key_attr="album",
    )
    logger.info("Found automatic tags for %s albums…", len(data))
    if dry_run:
        logger.info("Running in dry-run mode, not committing")
        return

    tags_tasks.add_tags_batch(
        data,
        model=models.Album,
    )
    return data


@celery.app.task(name="music.artists_set_tags_from_tracks")
@transaction.atomic
def artists_set_tags_from_tracks(ids=None, dry_run=False):
    qs = models.Artist.objects.filter(tagged_items__isnull=True).order_by("id")
    qs = qs.values_list("id", flat=True)
    if ids is not None:
        qs = qs.filter(pk__in=ids)
    data = tags_tasks.get_tags_from_foreign_key(
        ids=qs,
        foreign_key_model=models.Track,
        foreign_key_attr="artist_credit__artist",
    )
    logger.info("Found automatic tags for %s artists…", len(data))
    if dry_run:
        logger.info("Running in dry-run mode, not committing")
        return

    tags_tasks.add_tags_batch(
        data,
        model=models.Artist,
    )
    return data


def get_prunable_tracks(
    exclude_favorites=True, exclude_playlists=True, exclude_listenings=True
):
    """
    Returns a list of tracks with no associated uploads,
    excluding the one that were listened/favorited/included in playlists.
    """
    purgeable_tracks_with_upload = (
        models.Upload.objects.exclude(track=None)
        .filter(import_status="skipped")
        .values("track")
    )
    queryset = models.Track.objects.all()
    queryset = queryset.filter(
        Q(uploads__isnull=True) | Q(pk__in=purgeable_tracks_with_upload)
    )
    if exclude_favorites:
        queryset = queryset.filter(track_favorites__isnull=True)
    if exclude_playlists:
        queryset = queryset.filter(playlist_tracks__isnull=True)
    if exclude_listenings:
        queryset = queryset.filter(listenings__isnull=True)

    return queryset


def get_prunable_albums():
    return models.Album.objects.filter(tracks__isnull=True)


def get_prunable_artists():
    return models.Artist.objects.filter(artist_credit__isnull=True)


def update_library_entity(obj, data):
    """
    Given an obj and some updated fields, will persist the changes on the obj
    and also check if the entity need to be aliased with existing objs (i.e
    if a mbid was added on the obj, and match another entity with the same mbid)
    """
    for key, value in data.items():
        setattr(obj, key, value)

    # Todo: handle integrity error on unique fields (such as MBID)
    obj.save(update_fields=list(data.keys()))

    return obj


UPDATE_CONFIG = {
    "track": {
        "position": {},
        "title": {},
        "mbid": {},
        "disc_number": {},
        "copyright": {},
        "license": {
            "getter": lambda data, field: licenses.match(
                data.get("license"), data.get("copyright")
            )
        },
    },
    "album": {"title": {}, "mbid": {}, "release_date": {}},
}


@transaction.atomic
def update_track_metadata(audio_metadata, track):
    serializer = metadata.TrackMetadataSerializer(data=audio_metadata)
    serializer.is_valid(raise_exception=True)
    new_data = serializer.validated_data

    to_update = [
        ("track", track, lambda data: data),
        ("album", track.album, lambda data: data["album"]),
    ]
    for id, obj, data_getter in to_update:
        if not obj:
            continue
        obj_updated_fields = []
        try:
            obj_data = data_getter(new_data)
        except (IndexError, KeyError, TypeError):
            continue
        for field, config in UPDATE_CONFIG[id].items():
            field_getter = config.get(
                "getter", lambda data, field: data[config.get("field", field)]
            )
            try:
                new_value = field_getter(obj_data, field)
            except KeyError:
                continue
            old_value = getattr(obj, field)
            if new_value == old_value:
                continue
            obj_updated_fields.append(field)
            setattr(obj, field, new_value)

        if obj_updated_fields:
            obj.save(update_fields=obj_updated_fields)

    # Refresh artist credits when provided (artist_credit or legacy artists)
    ac_data = new_data.get("artist_credit") or _artists_list_to_artist_credit_data(
        new_data.get("artists", [])
    )
    if ac_data:
        credits = get_or_create_artists_credits_from_artist_credit_metadata(ac_data)
        if credits:
            track.artist_credit.set(credits)

    album_ac_data = None
    if track.album and "album" in new_data:
        album_ac_data = new_data["album"].get(
            "artist_credit"
        ) or _artists_list_to_artist_credit_data(new_data["album"].get("artists", []))
        if album_ac_data:
            credits = get_or_create_artists_credits_from_artist_credit_metadata(
                album_ac_data
            )
            if credits:
                track.album.artist_credit.set(credits)

    tags_models.set_tags(track, *new_data.get("tags", []))

    if track.album and "album" in new_data and new_data["album"].get("cover_data"):
        common_utils.attach_file(
            track.album, "attachment_cover", new_data["album"].get("cover_data")
        )


@celery.app.task(name="music.fs_import")
@celery.require_instance(models.Library.objects.all(), "library")
def fs_import(library, path, import_reference):
    if cache.get("fs-import:status") != "pending":
        raise ValueError("Invalid import status")

    command = import_files.Command()

    options = {
        "recursive": True,
        "library_id": str(library.uuid),
        "path": [os.path.join(settings.MUSIC_DIRECTORY_PATH, path)],
        "update_cache": True,
        "in_place": True,
        "reference": import_reference,
        "watch": False,
        "interactive": False,
        "batch_size": 1000,
        "async_": False,
        "prune": True,
        "replace": False,
        "verbosity": 1,
        "exit_on_failure": False,
        "outbox": False,
        "broadcast": False,
    }
    command.handle(**options)
