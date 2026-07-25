# Generated for client_data.PlaybackProgress

import django.db.models.deletion
import django.utils.timezone
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('client_data', '0002_clientpreference'),
    ]

    operations = [
        migrations.CreateModel(
            name="PlaybackProgress",
            fields=[
                (
                    "id",
                    models.AutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                (
                    "channel_uuid",
                    models.UUIDField(blank=True, db_index=True, null=True),
                ),
                ("position_ms", models.PositiveIntegerField(default=0)),
                (
                    "duration_ms",
                    models.PositiveIntegerField(blank=True, null=True),
                ),
                ("completed", models.BooleanField(default=False)),
                (
                    "updated_at",
                    models.DateTimeField(default=django.utils.timezone.now),
                ),
                (
                    "source_device",
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        related_name="playback_progress",
                        to="client_data.clientdevice",
                    ),
                ),
                (
                    "track",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="playback_progress",
                        to="music.track",
                    ),
                ),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="playback_progress",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                "ordering": ("-updated_at",),
                "unique_together": {("user", "track")},
            },
        ),
        migrations.AddIndex(
            model_name="playbackprogress",
            index=models.Index(
                fields=["user", "channel_uuid"], name="prog_user_channel"
            ),
        ),
        migrations.AddIndex(
            model_name="playbackprogress",
            index=models.Index(
                fields=["user", "updated_at"], name="prog_user_updated"
            ),
        ),
    ]
