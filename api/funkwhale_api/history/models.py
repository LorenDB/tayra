from django.db import models
from django.db.models import Q
from django.utils import timezone

from funkwhale_api.music.models import Track


def rich_listening_q():
    """
    Match listenings written by rich clients (Tayra dual-write / bulk import).

    Stock Funkwhale scrobbles only set track + user + creation_date. Rich rows
    carry at least one of duration, device, or client_session_id. Year-review
    and client UIs should ignore stock rows — they undercount and can crash
    clients when nested track payloads are incomplete.
    """
    return (
        Q(duration_seconds__isnull=False)
        | Q(source_device__isnull=False)
        | Q(client_session_id__isnull=False)
    )


class ListeningQuerySet(models.QuerySet):
    def rich(self):
        """Exclude thin stock scrobbles; keep rich client data only."""
        return self.filter(rich_listening_q())


class Listening(models.Model):
    # Indexed via Meta indexes (user, creation_date) — no standalone column index.
    creation_date = models.DateTimeField(
        default=timezone.now, null=True, blank=True
    )
    track = models.ForeignKey(
        Track, related_name="listenings", on_delete=models.CASCADE
    )
    user = models.ForeignKey(
        "users.User",
        related_name="listenings",
        null=True,
        blank=True,
        on_delete=models.CASCADE,
    )
    # Legacy Django session key (radios/history legacy). Leave alone; new clients
    # use client_session_id only.
    session_key = models.CharField(max_length=100, null=True, blank=True)

    # Rich client fields (all optional for backward compatibility)
    duration_seconds = models.PositiveIntegerField(
        null=True,
        blank=True,
        help_text="Actual seconds listened in this session (not full track length).",
    )
    source_device = models.ForeignKey(
        "client_data.ClientDevice",
        related_name="listenings",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
    )
    # Client-generated UUID for this play session. Not related to session_key.
    # Indexed via Meta composite + partial unique (no standalone column index).
    client_session_id = models.UUIDField(null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("-creation_date",)
        indexes = [
            models.Index(
                fields=["user", "creation_date"], name="hist_listen_user_date"
            ),
            models.Index(
                fields=["user", "track", "creation_date"],
                name="hist_listen_user_track_date",
            ),
            models.Index(
                fields=["user", "client_session_id"],
                name="hist_listen_user_session",
            ),
        ]
        constraints = [
            models.UniqueConstraint(
                fields=["user", "client_session_id"],
                condition=models.Q(client_session_id__isnull=False),
                name="hist_listen_unique_user_session",
            ),
        ]

    objects = ListeningQuerySet.as_manager()

    def get_activity_url(self):
        return f"{self.user.get_activity_url()}/listenings/tracks/{self.pk}"

    @property
    def is_rich(self):
        return (
            self.duration_seconds is not None
            or self.source_device_id is not None
            or self.client_session_id is not None
        )
