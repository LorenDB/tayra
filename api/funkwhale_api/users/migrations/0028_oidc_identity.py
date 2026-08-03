# Stable OIDC (issuer, sub) → local User binding.

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("users", "0027_remove_support_message_fields"),
    ]

    operations = [
        migrations.CreateModel(
            name="OidcIdentity",
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
                ("issuer", models.CharField(max_length=512)),
                ("subject", models.CharField(max_length=255)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("last_login_at", models.DateTimeField(blank=True, null=True)),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="oidc_identities",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
        ),
        migrations.AddConstraint(
            model_name="oidcidentity",
            constraint=models.UniqueConstraint(
                fields=("issuer", "subject"),
                name="users_oidcidentity_issuer_subject_uniq",
            ),
        ),
        migrations.AddIndex(
            model_name="oidcidentity",
            index=models.Index(
                fields=["user", "issuer"],
                name="users_oidci_user_id_issuer_idx",
            ),
        ),
    ]
