from django.db import models
from django.utils import timezone

from funkwhale_api.music.models import Track


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

    def get_activity_url(self):
        return f"{self.user.get_activity_url()}/listenings/tracks/{self.pk}"
