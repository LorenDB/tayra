# Widen TotpDevice.secret for encrypted-at-rest values (enc1:…).

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("users", "0028_oidc_identity"),
    ]

    operations = [
        migrations.AlterField(
            model_name="totpdevice",
            name="secret",
            field=models.CharField(max_length=512),
        ),
    ]
