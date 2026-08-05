import secrets
import uuid

from django.conf import settings
from django.db import models
from django.utils import timezone


def generate_share_token() -> str:
    """High-entropy URL-safe secret (~256 bits)."""
    return secrets.token_urlsafe(32)


class ShareLinkQuerySet(models.QuerySet):
    def active(self):
        now = timezone.now()
        return self.filter(revoked_at__isnull=True).filter(
            models.Q(expiration_date__isnull=True) | models.Q(expiration_date__gt=now)
        )


class ShareLink(models.Model):
    """Secret link granting unauthenticated listen access to one album or playlist."""

    OBJECT_ALBUM = "album"
    OBJECT_PLAYLIST = "playlist"
    OBJECT_TYPES = [
        (OBJECT_ALBUM, "Album"),
        (OBJECT_PLAYLIST, "Playlist"),
    ]

    uuid = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)
    token = models.CharField(max_length=64, unique=True, db_index=True)
    object_type = models.CharField(max_length=16, choices=OBJECT_TYPES)
    object_id = models.PositiveIntegerField()
    owner = models.ForeignKey(
        "users.User",
        related_name="share_links",
        on_delete=models.CASCADE,
    )
    creation_date = models.DateTimeField(default=timezone.now)
    expiration_date = models.DateTimeField(null=True, blank=True)
    revoked_at = models.DateTimeField(null=True, blank=True)
    label = models.CharField(max_length=100, blank=True, default="")

    objects = ShareLinkQuerySet.as_manager()

    class Meta:
        indexes = [
            models.Index(fields=["owner", "-creation_date"]),
            models.Index(fields=["object_type", "object_id"]),
        ]
        ordering = ["-creation_date"]

    def __str__(self):
        return f"ShareLink({self.object_type}:{self.object_id})"

    def save(self, *args, **kwargs):
        if not self.token:
            self.token = generate_share_token()
        return super().save(*args, **kwargs)

    @property
    def is_active(self) -> bool:
        if self.revoked_at is not None:
            return False
        if self.expiration_date is not None and self.expiration_date <= timezone.now():
            return False
        return True

    def get_absolute_url(self) -> str:
        base = settings.FUNKWHALE_URL.rstrip("/")
        return f"{base}/share/{self.token}"

    def get_object(self):
        """Return the shared Album or Playlist, or None if deleted."""
        if self.object_type == self.OBJECT_ALBUM:
            from funkwhale_api.music.models import Album

            return Album.objects.filter(pk=self.object_id).first()
        if self.object_type == self.OBJECT_PLAYLIST:
            from funkwhale_api.playlists.models import Playlist

            return Playlist.objects.filter(pk=self.object_id).first()
        return None

    def includes_track(self, track) -> bool:
        """Whether *track* is part of the shared album or playlist."""
        if self.object_type == self.OBJECT_ALBUM:
            return track.album_id == self.object_id
        if self.object_type == self.OBJECT_PLAYLIST:
            from funkwhale_api.playlists.models import PlaylistTrack

            return PlaylistTrack.objects.filter(
                playlist_id=self.object_id, track_id=track.pk
            ).exists()
        return False

    def track_queryset(self):
        """Tracks currently covered by this share, ordered for display."""
        from funkwhale_api.music.models import Track

        if self.object_type == self.OBJECT_ALBUM:
            return Track.objects.filter(album_id=self.object_id).order_by(
                "disc_number", "position", "id"
            )
        if self.object_type == self.OBJECT_PLAYLIST:
            from funkwhale_api.playlists.models import PlaylistTrack

            track_ids = list(
                PlaylistTrack.objects.filter(playlist_id=self.object_id)
                .order_by("index")
                .values_list("track_id", flat=True)
            )
            # Preserve playlist order.
            tracks = Track.objects.filter(pk__in=track_ids)
            by_id = {t.pk: t for t in tracks}
            ordered = [by_id[i] for i in track_ids if i in by_id]
            return ordered
        return Track.objects.none()
