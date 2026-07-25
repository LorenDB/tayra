# Generated manually for client_data.ClientPreference

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("client_data", "0001_initial"),
    ]

    operations = [
        migrations.CreateModel(
            name="ClientPreference",
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
                ("client_id", models.CharField(db_index=True, max_length=64)),
                ("key", models.CharField(max_length=255)),
                ("value", models.JSONField()),
                ("updated_at", models.DateTimeField(auto_now=True)),
                (
                    "device",
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="preferences",
                        to="client_data.clientdevice",
                    ),
                ),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="client_preferences",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                "ordering": ("key",),
            },
        ),
        migrations.AddIndex(
            model_name="clientpreference",
            index=models.Index(
                fields=["user", "client_id"], name="clientpref_user_client"
            ),
        ),
        migrations.AddConstraint(
            model_name="clientpreference",
            constraint=models.UniqueConstraint(
                condition=models.Q(device__isnull=True),
                fields=("user", "client_id", "key"),
                name="clientpref_unique_account_key",
            ),
        ),
        migrations.AddConstraint(
            model_name="clientpreference",
            constraint=models.UniqueConstraint(
                condition=models.Q(device__isnull=False),
                fields=("user", "client_id", "key", "device"),
                name="clientpref_unique_device_key",
            ),
        ),
    ]
