from django.db import models
from django.utils import timezone


class ClientDevice(models.Model):
    """Per-install device registry for multi-client rich data APIs."""

    uuid = models.UUIDField()  # client-generated
    user = models.ForeignKey(
        "users.User", related_name="client_devices", on_delete=models.CASCADE
    )
    name = models.CharField(max_length=255)
    client_id = models.CharField(
        max_length=64, help_text="e.g. tayra, funkwhale-web"
    )
    client_version = models.CharField(max_length=64, blank=True, default="")
    last_seen_at = models.DateTimeField(default=timezone.now)
    created_at = models.DateTimeField(default=timezone.now)
    is_active = models.BooleanField(default=True)

    class Meta:
        unique_together = ("user", "uuid")
        ordering = ("-last_seen_at",)

    def __str__(self):
        return f"{self.name} ({self.uuid})"
