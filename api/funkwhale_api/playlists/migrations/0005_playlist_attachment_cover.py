# Generated manually for custom playlist cover art support

import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("common", "0009_auto_20220627_1915"),
        ("playlists", "0004_auto_20180320_1713"),
    ]

    operations = [
        migrations.AddField(
            model_name="playlist",
            name="attachment_cover",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="covered_playlist",
                to="common.attachment",
            ),
        ),
    ]
