# Additive nullable rich fields on history.Listening

import django.db.models.deletion
import django.utils.timezone
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("client_data", "0001_initial"),
        ("history", "0002_auto_20180325_1433"),
    ]

    operations = [
        migrations.AddField(
            model_name="listening",
            name="duration_seconds",
            field=models.PositiveIntegerField(
                blank=True,
                help_text="Actual seconds listened in this session (not full track length).",
                null=True,
            ),
        ),
        migrations.AddField(
            model_name="listening",
            name="source_device",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="listenings",
                to="client_data.clientdevice",
            ),
        ),
        # No standalone db_index: covered by hist_listen_user_session + partial unique.
        migrations.AddField(
            model_name="listening",
            name="client_session_id",
            field=models.UUIDField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="listening",
            name="updated_at",
            field=models.DateTimeField(
                auto_now=True, default=django.utils.timezone.now
            ),
            preserve_default=False,
        ),
        # No standalone db_index on creation_date: covered by user-leading composites.
        migrations.AlterField(
            model_name="listening",
            name="creation_date",
            field=models.DateTimeField(
                blank=True,
                default=django.utils.timezone.now,
                null=True,
            ),
        ),
        migrations.AddIndex(
            model_name="listening",
            index=models.Index(
                fields=["user", "creation_date"], name="hist_listen_user_date"
            ),
        ),
        migrations.AddIndex(
            model_name="listening",
            index=models.Index(
                fields=["user", "track", "creation_date"],
                name="hist_listen_user_track_date",
            ),
        ),
        migrations.AddIndex(
            model_name="listening",
            index=models.Index(
                fields=["user", "client_session_id"],
                name="hist_listen_user_session",
            ),
        ),
        migrations.AddConstraint(
            model_name="listening",
            constraint=models.UniqueConstraint(
                condition=models.Q(client_session_id__isnull=False),
                fields=("user", "client_session_id"),
                name="hist_listen_unique_user_session",
            ),
        ),
    ]
