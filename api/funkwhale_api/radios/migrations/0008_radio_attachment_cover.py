# Generated manually for custom radio cover art support

import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("common", "0009_auto_20220627_1915"),
        ("radios", "0007_merge_20220715_0801"),
    ]

    operations = [
        migrations.AddField(
            model_name="radio",
            name="attachment_cover",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="covered_radio",
                to="common.attachment",
            ),
        ),
    ]
