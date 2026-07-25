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


class ClientPreference(models.Model):
    """Namespaced key/value client preferences (account- or device-scoped)."""

    user = models.ForeignKey(
        "users.User", related_name="client_preferences", on_delete=models.CASCADE
    )
    client_id = models.CharField(max_length=64, db_index=True)  # e.g. "tayra"
    device = models.ForeignKey(
        ClientDevice,
        null=True,
        blank=True,
        related_name="preferences",
        on_delete=models.CASCADE,
    )
    key = models.CharField(max_length=255)
    value = models.JSONField()
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            # Account-level (device IS NULL)
            models.UniqueConstraint(
                fields=["user", "client_id", "key"],
                condition=models.Q(device__isnull=True),
                name="clientpref_unique_account_key",
            ),
            # Device-scoped
            models.UniqueConstraint(
                fields=["user", "client_id", "key", "device"],
                condition=models.Q(device__isnull=False),
                name="clientpref_unique_device_key",
            ),
        ]
        indexes = [
            models.Index(fields=["user", "client_id"], name="clientpref_user_client"),
        ]
        ordering = ("key",)

    def __str__(self):
        scope = str(self.device.uuid) if self.device_id else "account"
        return f"{self.client_id}/{self.key} ({scope})"
