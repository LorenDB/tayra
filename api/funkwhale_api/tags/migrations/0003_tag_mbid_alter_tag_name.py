from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("tags", "0002_auto_20200803_1222"),
    ]

    operations = [
        migrations.AddField(
            model_name="tag",
            name="mbid",
            field=models.UUIDField(blank=True, db_index=True, null=True, unique=True),
        ),
        migrations.AlterField(
            model_name="tag",
            name="name",
            field=models.CharField(max_length=100, unique=True),
        ),
    ]
