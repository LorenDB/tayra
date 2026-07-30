# Generated manually for precalculated album duration

from django.db import migrations, models
from django.db.models import Min, Sum


def populate_album_durations(apps, schema_editor):
    Album = apps.get_model("music", "Album")
    Upload = apps.get_model("music", "Upload")

    # Batch by album id to avoid loading everything at once.
    album_ids = list(Album.objects.values_list("pk", flat=True))
    for album_id in album_ids:
        first_upload_ids = (
            Upload.objects.filter(track__album_id=album_id)
            .values("track_id")
            .annotate(first_id=Min("id"))
            .values_list("first_id", flat=True)
        )
        total = Upload.objects.filter(pk__in=first_upload_ids).aggregate(
            total=Sum("duration")
        )["total"]
        Album.objects.filter(pk=album_id).update(duration=total or 0)


def rewind_album_durations(apps, schema_editor):
    Album = apps.get_model("music", "Album")
    Album.objects.update(duration=0)


class Migration(migrations.Migration):

    dependencies = [
        ("music", "0057_auto_20221118_2108"),
    ]

    operations = [
        migrations.AddField(
            model_name="album",
            name="duration",
            field=models.PositiveIntegerField(db_index=True, default=0),
        ),
        migrations.RunPython(populate_album_durations, rewind_album_durations),
    ]
