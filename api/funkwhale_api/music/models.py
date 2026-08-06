import datetime
import logging
import os
import uuid

import arrow
import pydub
from django.conf import settings
from django.contrib.contenttypes.fields import GenericRelation
from django.contrib.postgres.indexes import GinIndex
from django.contrib.postgres.search import SearchVectorField
from django.core.exceptions import ObjectDoesNotExist
from django.core.files.base import ContentFile
from django.core.serializers.json import DjangoJSONEncoder
from django.db import models, transaction
from django.db.models import Count, JSONField, Min, Prefetch, Sum
from django.db.models.signals import post_delete, post_save, pre_save
from django.dispatch import receiver
from django.utils import timezone

from funkwhale_api import musicbrainz
from funkwhale_api.common import fields
from funkwhale_api.common import models as common_models
from funkwhale_api.common import utils as common_utils
from funkwhale_api.tags import models as tags_models

from . import importers, metadata, utils

logger = logging.getLogger(__name__)

ARTIST_CONTENT_CATEGORY_CHOICES = [
    ("music", "music"),
    ("podcast", "podcast"),
    ("other", "other"),
]


def empty_dict():
    return {}


class APIModelMixin(models.Model):
    mbid = models.UUIDField(unique=True, db_index=True, null=True, blank=True)
    uuid = models.UUIDField(unique=True, db_index=True, default=uuid.uuid4)
    api_includes = []
    creation_date = models.DateTimeField(default=timezone.now, db_index=True)
    import_hooks = []
    body_text = SearchVectorField(blank=True)

    class Meta:
        abstract = True
        ordering = ["-creation_date"]
        indexes = [
            GinIndex(fields=["body_text"]),
        ]

    @classmethod
    def get_or_create_from_api(cls, mbid):
        try:
            return cls.objects.get(mbid=mbid), False
        except cls.DoesNotExist:
            return cls.create_from_api(id=mbid), True

    def get_api_data(self):
        return self.__class__.api.get(id=self.mbid, includes=self.api_includes)[
            self.musicbrainz_model
        ]

    @classmethod
    def create_from_api(cls, **kwargs):
        if kwargs.get("id"):
            raw_data = cls.api.get(id=kwargs["id"], includes=cls.api_includes)[
                cls.musicbrainz_model
            ]
        else:
            raw_data = cls.api.search(**kwargs)[f"{cls.musicbrainz_model}-list"][0]
        cleaned_data = cls.clean_musicbrainz_data(raw_data)
        return importers.load(cls, cleaned_data, raw_data, cls.import_hooks)

    @classmethod
    def clean_musicbrainz_data(cls, data):
        cleaned_data = {}
        mapping = importers.Mapping(cls.musicbrainz_mapping)
        for key, value in data.items():
            try:
                cleaned_key, cleaned_value = mapping.from_musicbrainz(key, value)
                cleaned_data[cleaned_key] = cleaned_value
            except KeyError:
                pass
        return cleaned_data

    @property
    def musicbrainz_url(self):
        if self.mbid:
            return "https://musicbrainz.org/{}/{}".format(
                self.musicbrainz_model, self.mbid
            )

    @property
    def is_local(self) -> bool:
        return True

    def get_tags(self):
        return list(sorted(self.tagged_items.values_list("tag__name", flat=True)))


class License(models.Model):
    code = models.CharField(primary_key=True, max_length=100)
    url = models.URLField(max_length=500)

    # if true, license is a copyleft license, meaning that derivative
    # work must be shared under the same license
    copyleft = models.BooleanField()
    # if true, commercial use of the work is allowed
    commercial = models.BooleanField()
    # if true, attribution to the original author is required when reusing
    # the work
    attribution = models.BooleanField()
    # if true, derivative work are allowed
    derivative = models.BooleanField()
    # if true, redistribution of the wor is allowed
    redistribute = models.BooleanField()

    @property
    def conf(self):
        from . import licenses

        for row in licenses.LICENSES:
            if self.code == row["code"]:
                return row
        logger.warning("%s do not match any registered license", self.code)


class ArtistQuerySet(models.QuerySet):
    def with_albums_count(self):
        return self.annotate(_albums_count=models.Count("artist_credit__albums"))

    def with_albums(self):
        return self.prefetch_related(
            models.Prefetch(
                "artist_credit__albums",
                queryset=Album.objects.with_tracks_count().select_related(
                    "attachment_cover"
                ),
            )
        )

    def annotate_playable_by_user(self, user):
        tracks = (
            Upload.objects.playable_by(user)
            .filter(track__artist_credit__artist=models.OuterRef("id"))
            .order_by("id")
            .values("id")[:1]
        )
        subquery = models.Subquery(tracks)
        return self.annotate(is_playable_by_user=subquery)

    def playable_by(self, user, include=True):
        tracks = Track.objects.playable_by(user)
        matches = self.filter(
            pk__in=tracks.values("artist_credit__artist_id")
        ).values_list("pk")
        if include:
            return self.filter(pk__in=matches)
        else:
            return self.exclude(pk__in=matches)


class Artist(APIModelMixin):
    name = models.TextField()
    musicbrainz_model = "artist"
    musicbrainz_mapping = {
        "mbid": {"musicbrainz_field_name": "id"},
        "name": {"musicbrainz_field_name": "name"},
    }
    tagged_items = GenericRelation(tags_models.TaggedItem)
    description = models.ForeignKey(
        "common.Content", null=True, blank=True, on_delete=models.SET_NULL
    )
    attachment_cover = models.ForeignKey(
        "common.Attachment",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="covered_artist",
    )
    content_category = models.CharField(
        max_length=30,
        db_index=True,
        default="music",
        choices=ARTIST_CONTENT_CATEGORY_CHOICES,
        null=False,
    )
    modification_date = models.DateTimeField(default=timezone.now, db_index=True)
    api = musicbrainz.api.artists
    objects = ArtistQuerySet.as_manager()

    def __str__(self):
        return self.name

    def get_absolute_url(self):
        return f"/library/artists/{self.pk}"

    def get_moderation_url(self):
        return f"/manage/library/artists/{self.pk}"

    @classmethod
    def get_or_create_from_name(cls, name, **kwargs):
        kwargs.update({"name": name})
        return cls.objects.get_or_create(name__iexact=name, defaults=kwargs)

    @property
    def cover(self):
        return self.attachment_cover

    def get_channel(self):
        try:
            return self.channel
        except ObjectDoesNotExist:
            return None

    @property
    def albums(self):
        return Album.objects.filter(artist_credit__artist=self)

    def get_tracks_count(self):
        return Track.objects.filter(artist_credit__artist=self).count()


def import_artist_credit(v):
    """Convert MusicBrainz artist-credit list into ArtistCredit instances."""
    from funkwhale_api.common import preferences

    artists_credits = []
    for i, ac in enumerate(v):
        if isinstance(ac, str):
            continue
        artist, _created = Artist.get_or_create_from_api(mbid=ac["artist"]["id"])
        if "joinphrase" in ac:
            joinphrase = ac["joinphrase"]
        elif i < len(v) - 1:
            joinphrase = preferences.get("music__default_join_phrase") or ", "
        else:
            joinphrase = ""
        credit_name = ac.get("name", ac["artist"]["name"])
        artist_credit, _created = ArtistCredit.objects.get_or_create(
            artist=artist,
            credit=credit_name,
            index=i,
            joinphrase=joinphrase,
        )
        artists_credits.append(artist_credit)
    return artists_credits


def parse_date(v):
    d = arrow.get(v).date()
    return d


def import_tracks(instance, cleaned_data, raw_data):
    for track_data in raw_data["medium-list"][0]["track-list"]:
        track_cleaned_data = Track.clean_musicbrainz_data(track_data["recording"])
        track_cleaned_data["album"] = instance
        track_cleaned_data["position"] = int(track_data["position"])
        importers.load(Track, track_cleaned_data, track_data, Track.import_hooks)


class ArtistCreditQuerySet(models.QuerySet):
    def albums(self):
        albums_ids = self.prefetch_related("albums").values_list("albums", flat=True)
        return Album.objects.filter(id__in=albums_ids)


class ArtistCredit(APIModelMixin):
    artist = models.ForeignKey(
        Artist, related_name="artist_credit", on_delete=models.CASCADE
    )
    credit = models.CharField(
        null=True,
        blank=True,
        max_length=500,
    )
    joinphrase = models.CharField(
        null=True,
        blank=True,
        max_length=250,
    )
    index = models.IntegerField(
        null=True,
        blank=True,
    )

    objects = ArtistCreditQuerySet.as_manager()

    class Meta:
        ordering = ["index", "credit"]


class AlbumQuerySet(models.QuerySet):
    def with_tracks_count(self):
        return self.annotate(_tracks_count=models.Count("tracks"))

    def annotate_playable_by_user(self, user):
        tracks = (
            Upload.objects.playable_by(user)
            .filter(track__album=models.OuterRef("id"))
            .order_by("id")
            .values("id")[:1]
        )
        subquery = models.Subquery(tracks)
        return self.annotate(is_playable_by_user=subquery)

    def playable_by(self, user, include=True):
        tracks = Track.objects.playable_by(user)
        matches = self.filter(pk__in=tracks.values("album_id")).values_list("pk")
        if include:
            return self.filter(pk__in=matches)
        else:
            return self.exclude(pk__in=matches)


def compute_album_duration(album_id):
    """
    Total album duration in seconds: sum of one upload duration per track
    (lowest upload id per track).
    """
    if not album_id:
        return 0
    first_upload_ids = (
        Upload.objects.filter(track__album_id=album_id)
        .values("track_id")
        .annotate(first_id=Min("id"))
        .values_list("first_id", flat=True)
    )
    total = Upload.objects.filter(pk__in=first_upload_ids).aggregate(
        total=Sum("duration")
    )["total"]
    return total or 0


class Album(APIModelMixin):
    title = models.TextField()
    artist_credit = models.ManyToManyField(ArtistCredit, related_name="albums")
    release_date = models.DateField(null=True, blank=True, db_index=True)
    release_group_id = models.UUIDField(null=True, blank=True)
    # Precalculated total length in seconds (one upload per track).
    # Updated when tracks/uploads are added, modified, or removed.
    duration = models.PositiveIntegerField(default=0, db_index=True)
    attachment_cover = models.ForeignKey(
        "common.Attachment",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="covered_album",
    )
    TYPE_CHOICES = (("album", "Album"),)
    type = models.CharField(choices=TYPE_CHOICES, max_length=30, default="album")

    tagged_items = GenericRelation(tags_models.TaggedItem)

    description = models.ForeignKey(
        "common.Content", null=True, blank=True, on_delete=models.SET_NULL
    )

    api_includes = ["artist-credits", "recordings", "media", "release-groups"]
    api = musicbrainz.api.releases
    musicbrainz_model = "release"
    musicbrainz_mapping = {
        "mbid": {"musicbrainz_field_name": "id"},
        "position": {
            "musicbrainz_field_name": "release-list",
            "converter": lambda v: int(v[0]["medium-list"][0]["position"]),
        },
        "release_group_id": {
            "musicbrainz_field_name": "release-group",
            "converter": lambda v: v["id"],
        },
        "title": {"musicbrainz_field_name": "title"},
        "release_date": {"musicbrainz_field_name": "date", "converter": parse_date},
        "type": {"musicbrainz_field_name": "type", "converter": lambda v: v.lower()},
        "artist_credit": {
            "musicbrainz_field_name": "artist-credit",
            "converter": import_artist_credit,
        },
    }
    objects = AlbumQuerySet.as_manager()

    @property
    def cover(self):
        return self.attachment_cover

    def __str__(self):
        return self.title

    def get_absolute_url(self):
        return f"/library/albums/{self.pk}"

    def get_moderation_url(self):
        return f"/manage/library/albums/{self.pk}"

    def recalculate_duration(self, save=True):
        """Recompute and optionally persist stored duration for this album."""
        new_duration = compute_album_duration(self.pk)
        self.duration = new_duration
        if save and self.pk:
            type(self).objects.filter(pk=self.pk).update(duration=new_duration)
        return new_duration

    @classmethod
    def update_durations(cls, album_ids):
        """Recalculate stored duration for each album id in *album_ids*."""
        ids = {aid for aid in album_ids if aid}
        if not ids:
            return
        for album_id in ids:
            duration = compute_album_duration(album_id)
            cls.objects.filter(pk=album_id).update(duration=duration)

    @classmethod
    def get_or_create_from_title(cls, title, **kwargs):
        kwargs.update({"title": title})
        return cls.objects.get_or_create(title__iexact=title, defaults=kwargs)

    @property
    def get_artist_credit_string(self):
        return utils.get_artist_credit_string(self)

    def get_artists_list(self):
        return [ac.artist for ac in self.artist_credit.all()]

    @property
    def artist(self):
        artists = self.get_artists_list()
        return artists[0] if artists else None


def import_tags(instance, cleaned_data, raw_data):
    MINIMUM_COUNT = 2
    tags_to_add = []
    for tag_data in raw_data.get("tag-list", []):
        try:
            if int(tag_data["count"]) < MINIMUM_COUNT:
                continue
        except ValueError:
            continue
        tags_to_add.append(tag_data["name"])

    tags_models.add_tags(instance, *tags_to_add)


def import_album(v):
    a = Album.get_or_create_from_api(mbid=v[0]["id"])[0]
    return a


class TrackQuerySet(models.QuerySet):
    def for_nested_serialization(self):
        return self.prefetch_related(
            "artist_credit",
            "artist_credit__artist",
            Prefetch(
                "album",
                queryset=Album.objects.prefetch_related(
                    "artist_credit", "artist_credit__artist", "attachment_cover"
                ).annotate(_prefetched_tracks_count=Count("tracks")),
            ),
        )

    def annotate_playable_by_user(self, user):
        files = (
            Upload.objects.playable_by(user)
            .filter(track=models.OuterRef("id"))
            .order_by("id")
            .values("id")[:1]
        )
        subquery = models.Subquery(files)
        return self.annotate(is_playable_by_user=subquery)

    def playable_by(self, user, include=True):
        if settings.MUSIC_USE_DENORMALIZATION:
            if user is not None:
                query = models.Q(user=None) | models.Q(user=user)
            else:
                query = models.Q(user=None, internal=False)
            if not include:
                query = ~query
            return self.filter(pk__in=TrackActor.objects.filter(query).values("track"))
        files = Upload.objects.playable_by(user, include)
        matches = self.filter(uploads__in=files).values_list("pk")
        if include:
            return self.filter(pk__in=matches)
        else:
            return self.exclude(pk__in=matches)

    def with_playable_uploads(self, user):
        uploads = Upload.objects.playable_by(user)
        return self.prefetch_related(
            models.Prefetch("uploads", queryset=uploads, to_attr="playable_uploads")
        )

    def order_for_album(self):
        """
        Order by disc number then position
        """
        return self.order_by("disc_number", "position", "title")


def get_artist(release_list):
    return Artist.get_or_create_from_api(
        mbid=release_list[0]["artist-credits"][0]["artists"]["id"]
    )[0]


class Track(APIModelMixin):
    mbid = models.UUIDField(db_index=True, null=True, blank=True)
    title = models.TextField()
    artist_credit = models.ManyToManyField(ArtistCredit, related_name="tracks")
    disc_number = models.PositiveIntegerField(null=True, blank=True)
    position = models.PositiveIntegerField(null=True, blank=True)
    album = models.ForeignKey(
        Album, related_name="tracks", null=True, blank=True, on_delete=models.CASCADE
    )
    license = models.ForeignKey(
        License,
        null=True,
        blank=True,
        on_delete=models.DO_NOTHING,
        related_name="tracks",
    )
    # Music entities are attributed to actors, to validate that updates occur
    # from an authorized account. On top of that, we consider the instance actor
    # can update anything under it's own domain
    copyright = models.TextField(null=True, blank=True)
    description = models.ForeignKey(
        "common.Content", null=True, blank=True, on_delete=models.SET_NULL
    )
    attachment_cover = models.ForeignKey(
        "common.Attachment",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="covered_track",
    )
    downloads_count = models.PositiveIntegerField(default=0)
    musicbrainz_model = "recording"
    api = musicbrainz.api.recordings
    api_includes = ["artist-credits", "releases", "media", "tags"]
    musicbrainz_mapping = {
        "mbid": {"musicbrainz_field_name": "id"},
        "title": {"musicbrainz_field_name": "title"},
        "artist_credit": {
            "musicbrainz_field_name": "artist-credit",
            "converter": import_artist_credit,
        },
        "album": {"musicbrainz_field_name": "release-list", "converter": import_album},
    }
    import_hooks = [import_tags]
    objects = TrackQuerySet.as_manager()
    tagged_items = GenericRelation(tags_models.TaggedItem)

    class Meta:
        ordering = ["album", "disc_number", "position"]
        indexes = [
            GinIndex(fields=["body_text"]),
        ]

    def __str__(self):
        return self.title

    def get_absolute_url(self):
        return f"/library/tracks/{self.pk}"

    def get_moderation_url(self):
        return f"/manage/library/tracks/{self.pk}"

    @property
    def get_artist_credit_string(self):
        return utils.get_artist_credit_string(self)

    def get_artists_list(self):
        return [ac.artist for ac in self.artist_credit.all()]

    @property
    def artist(self):
        artists = self.get_artists_list()
        return artists[-1] if artists else None

    @property
    def full_name(self):
        try:
            return (
                f"{self.get_artist_credit_string} - {self.album.title} - {self.title}"
            )
        except AttributeError:
            return f"{self.get_artist_credit_string} - {self.title}"

    @property
    def cover(self):
        return self.attachment_cover

    def get_activity_url(self):
        if self.mbid:
            return f"https://musicbrainz.org/recording/{self.mbid}"
        return settings.FUNKWHALE_URL + f"/tracks/{self.pk}"

    @classmethod
    def get_or_create_from_title(cls, title, **kwargs):
        kwargs.update({"title": title})
        return cls.objects.get_or_create(title__iexact=title, defaults=kwargs)

    @classmethod
    def get_or_create_from_release(cls, release_mbid, mbid):
        release_mbid = str(release_mbid)
        mbid = str(mbid)
        try:
            return cls.objects.get(mbid=mbid), False
        except cls.DoesNotExist:
            pass

        album = Album.get_or_create_from_api(release_mbid)[0]
        data = musicbrainz.client.api.releases.get(
            str(album.mbid), includes=Album.api_includes
        )
        tracks = [t for m in data["release"]["medium-list"] for t in m["track-list"]]
        track_data = None
        for track in tracks:
            if track["recording"]["id"] == str(mbid):
                track_data = track
                break
        if not track_data:
            raise ValueError("No track found matching this ID")

        artists_credits = []
        for i, ac in enumerate(track_data["recording"]["artist-credit"]):
            try:
                ac_mbid = ac["artist"]["id"]
            except TypeError:
                # it's probably a string, like "feat."
                continue

            track_artist = Artist.get_or_create_from_api(ac_mbid)[0]
            joinphrase = ac.get("joinphrase", "") or ""
            artist_credit, _created = ArtistCredit.objects.get_or_create(
                artist=track_artist,
                credit=ac["artist"]["name"],
                joinphrase=joinphrase,
                index=i,
            )
            artists_credits.append(artist_credit)

        if artists_credits:
            album.artist_credit.set(artists_credits)

        track = cls.objects.update_or_create(
            mbid=mbid,
            defaults={
                "position": int(track["position"]),
                "title": track["recording"]["title"],
                "album": album,
            },
        )
        track[0].artist_credit.set(artists_credits)
        return track

    @property
    def listen_url(self) -> str:
        # Not using reverse because this is slow
        return f"/api/v1/listen/{self.uuid}/"

    @property
    def local_license(self):
        """
        Since license primary keys are strings, and we can get the data
        from our hardcoded licenses.LICENSES list, there is no need
        for extra SQL joins / queries.
        """
        from . import licenses

        return licenses.LICENSES_BY_ID.get(self.license_id)


class UploadQuerySet(common_models.NullsLastQuerySet):
    def in_place(self, include=True):
        query = models.Q(source__startswith="file://") & (
            models.Q(audio_file="") | models.Q(audio_file=None)
        )
        if not include:
            query = ~query
        return self.filter(query)

    def playable_by(self, user, include=True):
        libraries = Library.objects.viewable_by(user)

        if include:
            return self.filter(
                library__in=libraries, import_status__in=["finished", "skipped"]
            )
        return self.exclude(
            library__in=libraries, import_status__in=["finished", "skipped"]
        )

    def with_file(self):
        return self.exclude(audio_file=None).exclude(audio_file="")


TRACK_FILE_IMPORT_STATUS_CHOICES = (
    ("draft", "Draft"),
    ("pending", "Pending"),
    ("finished", "Finished"),
    ("errored", "Errored"),
    ("skipped", "Skipped"),
)


def get_file_path(instance, filename):
    if isinstance(instance, UploadVersion):
        return common_utils.ChunkedPath("transcoded")(instance, filename)

    return common_utils.ChunkedPath("tracks")(instance, filename)


def get_import_reference():
    return str(uuid.uuid4())


class Upload(models.Model):
    uuid = models.UUIDField(unique=True, db_index=True, default=uuid.uuid4)
    track = models.ForeignKey(
        Track, related_name="uploads", on_delete=models.CASCADE, null=True, blank=True
    )
    audio_file = models.FileField(upload_to=get_file_path, max_length=255)
    source = models.CharField(
        # URL validators are not flexible enough for our file:// and upload:// schemes
        null=True,
        blank=True,
        max_length=500,
    )
    creation_date = models.DateTimeField(default=timezone.now, db_index=True)
    modification_date = models.DateTimeField(default=timezone.now, null=True)
    accessed_date = models.DateTimeField(null=True, blank=True)
    duration = models.IntegerField(null=True, blank=True)
    size = models.IntegerField(null=True, blank=True)
    bitrate = models.IntegerField(null=True, blank=True)
    acoustid_track_id = models.UUIDField(null=True, blank=True)
    mimetype = models.CharField(null=True, blank=True, max_length=200)
    library = models.ForeignKey(
        "library",
        null=True,
        blank=True,
        related_name="uploads",
        on_delete=models.CASCADE,
    )

    # metadata from imports
    metadata = JSONField(
        default=empty_dict, max_length=50000, encoder=DjangoJSONEncoder, blank=True
    )
    import_date = models.DateTimeField(null=True, blank=True)
    # optional metadata provided during import
    import_metadata = JSONField(
        default=empty_dict, max_length=50000, encoder=DjangoJSONEncoder, blank=True
    )
    # status / error details for the import
    import_status = models.CharField(
        default="pending", choices=TRACK_FILE_IMPORT_STATUS_CHOICES, max_length=25
    )
    # a short reference provided by the client to group multiple files
    # in the same import
    import_reference = models.CharField(max_length=50, default=get_import_reference)

    # optional metadata about import results (error messages, etc.)
    import_details = JSONField(
        default=empty_dict, max_length=50000, encoder=DjangoJSONEncoder, blank=True
    )
    downloads_count = models.PositiveIntegerField(default=0)

    # stores checksums such as `sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
    checksum = models.CharField(max_length=100, db_index=True, null=True, blank=True)

    objects = UploadQuerySet.as_manager()

    @property
    def is_local(self) -> bool:
        return True

    @property
    def filename(self) -> str:
        return f"{self.track.full_name}.{self.extension}"

    @property
    def extension(self):
        try:
            return utils.MIMETYPE_TO_EXTENSION[self.mimetype]
        except KeyError:
            pass
        if self.audio_file:
            return os.path.splitext(self.audio_file.name)[-1].replace(".", "", 1)
        if self.in_place_path:
            return os.path.splitext(self.in_place_path)[-1].replace(".", "", 1)

    def get_file_size(self):
        if self.audio_file:
            return self.audio_file.size

        if self.source and self.source.startswith("file://"):
            path = utils.resolve_inplace_source(self.source)
            if path is None:
                return None
            return os.path.getsize(path)

    def get_audio_file(self):
        if self.audio_file:
            return self.audio_file.open()
        if self.source and self.source.startswith("file://"):
            path = utils.resolve_inplace_source(self.source)
            if path is None:
                return None
            return open(path, "rb")

    def get_audio_data(self):
        audio_file = self.get_audio_file()
        if not audio_file:
            return
        audio_data = utils.get_audio_file_data(audio_file)
        if not audio_data:
            return
        return {
            "duration": int(audio_data["length"]),
            "bitrate": audio_data["bitrate"],
            "size": self.get_file_size(),
        }

    def get_audio_segment(self):
        input = self.get_audio_file()
        if not input:
            return

        audio = pydub.AudioSegment.from_file(input)
        return audio

    def save(self, **kwargs):
        if not self.mimetype:
            if self.audio_file:
                self.mimetype = utils.guess_mimetype(self.audio_file)
            elif self.source and self.source.startswith("file://"):
                self.mimetype = utils.guess_mimetype_from_name(self.source)
        if not self.size and self.audio_file:
            self.size = self.audio_file.size
        if not self.checksum:
            try:
                audio_file = self.get_audio_file()
            except FileNotFoundError:
                pass
            else:
                if audio_file:
                    self.checksum = common_utils.get_file_hash(audio_file)

        return super().save(**kwargs)

    def get_metadata(self):
        audio_file = self.get_audio_file()
        if not audio_file:
            return
        return metadata.Metadata(audio_file)

    @property
    def listen_url(self) -> str:
        return self.track.listen_url + f"?upload={self.uuid}"

    def get_listen_url(self, to=None, download=True) -> str:
        url = self.listen_url
        if to:
            url += f"&to={to}"
        if not download:
            url += "&download=false"

        return url

    @property
    def listen_url_no_download(self):
        # Not using reverse because this is slow
        return self.listen_url + "&download=false"

    def get_transcoded_version(self, format, max_bitrate=None):
        if format:
            mimetype = utils.EXTENSION_TO_MIMETYPE[format]
        else:
            mimetype = self.mimetype or "audio/mpeg"
            format = utils.MIMETYPE_TO_EXTENSION[mimetype]

        existing_versions = self.versions.filter(mimetype=mimetype)
        if max_bitrate is not None:
            # we don't want to transcode if a 320kbps version is available
            # and we're requestiong 300kbps
            acceptable_max_bitrate = max_bitrate * 1.2
            acceptable_min_bitrate = max_bitrate * 0.8
            existing_versions = existing_versions.filter(
                bitrate__gte=acceptable_min_bitrate, bitrate__lte=acceptable_max_bitrate
            ).order_by("-bitrate")
        if existing_versions:
            # we found an existing version, no need to transcode again
            return existing_versions[0]

        return self.create_transcoded_version(mimetype, format, bitrate=max_bitrate)

    @transaction.atomic
    def create_transcoded_version(self, mimetype, format, bitrate):
        # we create the version with an empty file, then
        # we'll write to it
        f = ContentFile(b"")
        bitrate = min(bitrate or 320000, self.bitrate or 320000)
        version = self.versions.create(mimetype=mimetype, bitrate=bitrate, size=0)
        # we keep the same name, but we update the extension
        new_name = (
            os.path.splitext(os.path.basename(self.audio_file.name))[0] + f".{format}"
        )
        version.audio_file.save(new_name, f)
        utils.transcode_audio(
            audio=self.get_audio_segment(),
            output=version.audio_file,
            output_format=utils.MIMETYPE_TO_EXTENSION[mimetype],
            bitrate=str(bitrate),
        )
        version.size = version.audio_file.size
        version.save(update_fields=["size"])

        return version

    @property
    def in_place_path(self):
        if not self.source or not self.source.startswith("file://"):
            return
        path = utils.resolve_inplace_source(self.source)
        return str(path) if path is not None else None

    @property
    def audio_file_path(self):
        if not self.audio_file:
            return None
        try:
            return self.audio_file.path
        except NotImplementedError:
            # external storage
            return self.audio_file.name

    def get_all_tagged_items(self):
        track_tags = self.track.tagged_items.all()
        album_tags = (
            self.track.album.tagged_items.all()
            if self.track.album
            else tags_models.TaggedItem.objects.none()
        )
        artist_tags = tags_models.TaggedItem.objects.none()
        for ac in self.track.artist_credit.all():
            artist_tags = artist_tags | ac.artist.tagged_items.all()

        items = (track_tags | album_tags | artist_tags).order_by("tag__name")
        return items


MIMETYPE_CHOICES = [(mt, ext) for ext, mt in utils.AUDIO_EXTENSIONS_AND_MIMETYPE]


class UploadVersion(models.Model):
    upload = models.ForeignKey(
        Upload, related_name="versions", on_delete=models.CASCADE
    )
    mimetype = models.CharField(max_length=50, choices=MIMETYPE_CHOICES)
    creation_date = models.DateTimeField(default=timezone.now)
    accessed_date = models.DateTimeField(null=True, blank=True)
    audio_file = models.FileField(upload_to=get_file_path, max_length=255)
    bitrate = models.PositiveIntegerField()
    size = models.IntegerField()

    class Meta:
        unique_together = ("upload", "mimetype", "bitrate")

    @property
    def filename(self) -> str:
        try:
            return (
                self.upload.track.full_name
                + "."
                + utils.MIMETYPE_TO_EXTENSION[self.mimetype]
            )
        except KeyError:
            return self.upload.filename

    @property
    def audio_file_path(self):
        if not self.audio_file:
            return None
        try:
            return self.audio_file.path
        except NotImplementedError:
            # external storage
            return self.audio_file.name


IMPORT_STATUS_CHOICES = (
    ("pending", "Pending"),
    ("finished", "Finished"),
    ("errored", "Errored"),
    ("skipped", "Skipped"),
)


class ImportBatch(models.Model):
    uuid = models.UUIDField(unique=True, db_index=True, default=uuid.uuid4)
    IMPORT_BATCH_SOURCES = [
        ("api", "api"),
        ("shell", "shell"),
    ]
    source = models.CharField(
        max_length=30, default="api", choices=IMPORT_BATCH_SOURCES
    )
    creation_date = models.DateTimeField(default=timezone.now)
    submitted_by = models.ForeignKey(
        "users.User",
        related_name="imports",
        null=True,
        blank=True,
        on_delete=models.CASCADE,
    )
    status = models.CharField(
        choices=IMPORT_STATUS_CHOICES, default="pending", max_length=30
    )
    import_request = models.ForeignKey(
        "requests.ImportRequest",
        related_name="import_batches",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
    )
    library = models.ForeignKey(
        "Library",
        related_name="import_batches",
        null=True,
        blank=True,
        on_delete=models.CASCADE,
    )

    class Meta:
        ordering = ["-creation_date"]

    def __str__(self):
        return str(self.pk)

    def update_status(self):
        old_status = self.status
        self.status = utils.compute_status(self.jobs.all())
        if self.status == old_status:
            return
        self.save(update_fields=["status"])


class ImportJob(models.Model):
    uuid = models.UUIDField(unique=True, db_index=True, default=uuid.uuid4)
    replace_if_duplicate = models.BooleanField(default=False)
    batch = models.ForeignKey(
        ImportBatch, related_name="jobs", on_delete=models.CASCADE
    )
    upload = models.ForeignKey(
        Upload, related_name="jobs", null=True, blank=True, on_delete=models.CASCADE
    )
    source = models.CharField(max_length=500)
    mbid = models.UUIDField(editable=False, null=True, blank=True)

    status = models.CharField(
        choices=IMPORT_STATUS_CHOICES, default="pending", max_length=30
    )
    audio_file = models.FileField(
        upload_to="imports/%Y/%m/%d", max_length=255, null=True, blank=True
    )

    audio_file_size = models.IntegerField(null=True, blank=True)

    class Meta:
        ordering = ("id",)

    def save(self, **kwargs):
        if self.audio_file and not self.audio_file_size:
            self.audio_file_size = self.audio_file.size
        return super().save(**kwargs)


LIBRARY_PRIVACY_LEVEL_CHOICES = [
    (k, l) for k, l in fields.PRIVACY_LEVEL_CHOICES if k != "followers"
]


class LibraryQuerySet(models.QuerySet):
    def with_follows(self, user):
        from funkwhale_api.audio.models import ChannelSubscription

        return self.prefetch_related(
            models.Prefetch(
                "channel__subscriptions",
                queryset=ChannelSubscription.objects.filter(user=user),
                to_attr="_follows",
            )
        )

    def viewable_by(self, user):
        from funkwhale_api.audio.models import ChannelSubscription

        if user is None:
            return self.filter(privacy_level="everyone")

        me_query = models.Q(privacy_level="me", owner=user)
        instance_query = models.Q(privacy_level="instance")
        subscribed_channels = ChannelSubscription.objects.filter(
            user=user, approved=True
        ).values_list("channel__library", flat=True)

        return self.filter(
            me_query
            | instance_query
            | models.Q(privacy_level="everyone")
            | models.Q(pk__in=subscribed_channels)
        )


class Library(models.Model):
    uuid = models.UUIDField(unique=True, db_index=True, default=uuid.uuid4)
    owner = models.ForeignKey(
        "users.User",
        related_name="libraries",
        on_delete=models.CASCADE,
        null=True,
        blank=True,
    )
    creation_date = models.DateTimeField(default=timezone.now)
    name = models.CharField(max_length=100)
    description = models.TextField(max_length=5000, null=True, blank=True)
    privacy_level = models.CharField(
        choices=LIBRARY_PRIVACY_LEVEL_CHOICES, default="me", max_length=25
    )
    uploads_count = models.PositiveIntegerField(default=0)
    objects = LibraryQuerySet.as_manager()

    def __str__(self):
        return self.name

    def get_absolute_url(self) -> str:
        return f"/library/{self.uuid}"

    @property
    def is_local(self) -> bool:
        return True

    def schedule_scan(self, user, force=False):
        latest_scan = (
            self.scans.exclude(status="errored").order_by("-creation_date").first()
        )
        delay_between_scans = datetime.timedelta(seconds=3600 * 24)
        now = timezone.now()
        if (
            not force
            and latest_scan
            and latest_scan.creation_date + delay_between_scans > now
        ):
            return

        scan = self.scans.create(total_files=self.uploads_count, submitted_by=user)
        return scan

    def get_channel(self):
        try:
            return self.channel
        except ObjectDoesNotExist:
            return None

    def latest_scan(self):
        return self.scans.order_by("-creation_date").first()


SCAN_STATUS = [
    ("pending", "pending"),
    ("scanning", "scanning"),
    ("errored", "errored"),
    ("finished", "finished"),
]


class LibraryScan(models.Model):
    submitted_by = models.ForeignKey(
        "users.User", null=True, blank=True, on_delete=models.CASCADE
    )
    library = models.ForeignKey(Library, related_name="scans", on_delete=models.CASCADE)
    total_files = models.PositiveIntegerField(default=0)
    processed_files = models.PositiveIntegerField(default=0)
    errored_files = models.PositiveIntegerField(default=0)
    status = models.CharField(default="pending", max_length=25)
    creation_date = models.DateTimeField(default=timezone.now)
    modification_date = models.DateTimeField(null=True, blank=True)


class TrackActor(models.Model):
    """
    Denormalization table to store all playable tracks for a given user
    Empty user means the track is public or internal (cf internal flag too)
    """

    id = models.BigAutoField(primary_key=True)
    user = models.ForeignKey(
        "users.User",
        on_delete=models.CASCADE,
        related_name="track_actor_items",
        blank=True,
        null=True,
    )
    track = models.ForeignKey(
        Track, on_delete=models.CASCADE, related_name="track_actor_items"
    )
    upload = models.ForeignKey(
        Upload, on_delete=models.CASCADE, related_name="track_actor_items"
    )
    internal = models.BooleanField(default=False, db_index=True)

    class Meta:
        unique_together = ("track", "user", "internal", "upload")

    @classmethod
    def get_objs(cls, library, user_ids, upload_and_track_ids):
        from funkwhale_api.audio.models import ChannelSubscription

        upload_and_track_ids = upload_and_track_ids or library.uploads.filter(
            import_status="finished", track__isnull=False
        ).values_list("id", "track")
        objs = []
        if library.privacy_level == "me":
            if library.get_channel():
                subscription_queryset = library.channel.subscriptions
            else:
                subscription_queryset = ChannelSubscription.objects.filter(
                    channel__library=library
                )
            subscription_queryset = subscription_queryset.filter(approved=True)
            if user_ids:
                subscription_queryset = subscription_queryset.filter(
                    user__pk__in=user_ids
                )
            final_user_ids = list(subscription_queryset.values_list("user", flat=True))

            owner = library.owner
            if owner and (not user_ids or owner.pk in final_user_ids):
                final_user_ids.append(owner.pk)
            for user_id in final_user_ids:
                for upload_id, track_id in upload_and_track_ids:
                    objs.append(
                        cls(user_id=user_id, track_id=track_id, upload_id=upload_id)
                    )

        elif library.privacy_level == "instance":
            for upload_id, track_id in upload_and_track_ids:
                objs.append(
                    cls(
                        user_id=None,
                        track_id=track_id,
                        upload_id=upload_id,
                        internal=True,
                    )
                )
        elif library.privacy_level == "everyone":
            for upload_id, track_id in upload_and_track_ids:
                objs.append(cls(user_id=None, track_id=track_id, upload_id=upload_id))
        return objs

    @classmethod
    def create_entries(
        cls, library, delete_existing=True, actor_ids=None, upload_and_track_ids=None
    ):
        if not settings.MUSIC_USE_DENORMALIZATION:
            # skip
            return
        if delete_existing:
            to_delete = cls.objects.filter(upload__library=library)
            if actor_ids:
                to_delete = to_delete.filter(user__pk__in=actor_ids)
            # we don't use .delete() here because we don't want signals to fire
            to_delete._raw_delete(to_delete.db)

        objs = cls.get_objs(
            library, user_ids=actor_ids, upload_and_track_ids=upload_and_track_ids
        )
        return cls.objects.bulk_create(objs, ignore_conflicts=True, batch_size=5000)


@receiver(post_save, sender=ImportJob)
def update_batch_status(sender, instance, **kwargs):
    instance.batch.update_status()


@receiver(post_save, sender=Upload)
def update_denormalization_track_actor(sender, instance, created, **kwargs):
    if (
        created
        and settings.MUSIC_USE_DENORMALIZATION
        and instance.track_id
        and instance.import_status == "finished"
    ):
        TrackActor.create_entries(
            instance.library,
            delete_existing=False,
            upload_and_track_ids=[(instance.pk, instance.track_id)],
        )


# ── Album duration denormalization ─────────────────────────────────────────


def _album_ids_for_tracks(track_ids):
    track_ids = [tid for tid in track_ids if tid]
    if not track_ids:
        return set()
    return set(
        Track.objects.filter(pk__in=track_ids)
        .exclude(album_id=None)
        .values_list("album_id", flat=True)
    )


@receiver(pre_save, sender=Upload)
def cache_upload_album_ids_for_duration(sender, instance, **kwargs):
    """Remember album(s) that may need duration refresh after this upload save."""
    album_ids = set()
    if instance.pk:
        old = (
            Upload.objects.filter(pk=instance.pk)
            .values_list("track_id", "track__album_id")
            .first()
        )
        if old:
            old_track_id, old_album_id = old
            instance._duration_old_track_id = old_track_id
            if old_album_id:
                album_ids.add(old_album_id)
    instance._duration_album_ids = album_ids


@receiver(post_save, sender=Upload)
def update_album_duration_on_upload_save(sender, instance, created, **kwargs):
    update_fields = kwargs.get("update_fields")
    if update_fields is not None and not created:
        relevant = {"duration", "track", "track_id"}
        if not relevant.intersection(update_fields):
            return

    album_ids = set(getattr(instance, "_duration_album_ids", set()) or set())
    if instance.track_id:
        album_ids |= _album_ids_for_tracks([instance.track_id])
    if album_ids:
        Album.update_durations(album_ids)


@receiver(post_delete, sender=Upload)
def update_album_duration_on_upload_delete(sender, instance, **kwargs):
    album_ids = _album_ids_for_tracks([instance.track_id])
    if album_ids:
        Album.update_durations(album_ids)


@receiver(pre_save, sender=Track)
def cache_track_album_id_for_duration(sender, instance, **kwargs):
    if instance.pk:
        old_album_id = (
            Track.objects.filter(pk=instance.pk)
            .values_list("album_id", flat=True)
            .first()
        )
        instance._duration_old_album_id = old_album_id
    else:
        instance._duration_old_album_id = None


@receiver(post_save, sender=Track)
def update_album_duration_on_track_save(sender, instance, created, **kwargs):
    update_fields = kwargs.get("update_fields")
    if update_fields is not None and not created:
        if "album" not in update_fields and "album_id" not in update_fields:
            return

    album_ids = set()
    old_album_id = getattr(instance, "_duration_old_album_id", None)
    if old_album_id:
        album_ids.add(old_album_id)
    if instance.album_id:
        album_ids.add(instance.album_id)
    if album_ids:
        Album.update_durations(album_ids)


@receiver(post_delete, sender=Track)
def update_album_duration_on_track_delete(sender, instance, **kwargs):
    if instance.album_id:
        Album.update_durations([instance.album_id])


@receiver(pre_save, sender=Library)
def set_privacy_level_updated(sender, instance, update_fields, **kwargs):
    if not instance.pk:
        return
    if update_fields is not None and "privacy_level" not in update_fields:
        return
    db_value = instance.__class__.objects.filter(pk=instance.pk).values_list(
        "privacy_level", flat=True
    )[0]
    if db_value != instance.privacy_level:
        # Needed to update denormalized permissions
        setattr(instance, "_privacy_level_updated", True)


@receiver(post_save, sender=Library)
def update_denormalization_track_user_library_privacy_level(
    sender, instance, created, **kwargs
):
    if created:
        return
    updated = getattr(instance, "_privacy_level_updated", False)
    if updated:
        TrackActor.create_entries(instance)


@receiver(post_save, sender=ImportBatch)
def update_request_status(sender, instance, created, **kwargs):
    update_fields = kwargs.get("update_fields", []) or []
    if not instance.import_request:
        return

    if not created and "status" not in update_fields:
        return

    r_status = instance.import_request.status
    status = instance.status

    if status == "pending" and r_status == "pending":
        # let's mark the request as accepted since we started an import
        instance.import_request.status = "accepted"
        return instance.import_request.save(update_fields=["status"])

    if status == "finished" and r_status == "accepted":
        # let's mark the request as imported since the import is over
        instance.import_request.status = "imported"
        return instance.import_request.save(update_fields=["status"])
