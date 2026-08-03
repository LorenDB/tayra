# Generated manually for Tayra fork — drop unused support-message display dates.

from django.db import migrations


class Migration(migrations.Migration):
    dependencies = [
        ("users", "0026_remove_oidc_instance_preferences"),
    ]

    operations = [
        migrations.RemoveField(
            model_name="user",
            name="funkwhale_support_message_display_date",
        ),
        migrations.RemoveField(
            model_name="user",
            name="instance_support_message_display_date",
        ),
    ]
