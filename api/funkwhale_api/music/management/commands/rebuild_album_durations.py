from django.core.management.base import BaseCommand

from funkwhale_api.music import models


class Command(BaseCommand):
    help = "Recalculate and store Album.duration for all albums (or a subset)."

    def add_arguments(self, parser):
        parser.add_argument(
            "--album-id",
            type=int,
            action="append",
            dest="album_ids",
            default=None,
            help="Limit to one or more album IDs (repeatable)",
        )
        parser.add_argument(
            "--batch-size",
            type=int,
            default=500,
            help="How many album IDs to process per progress line",
        )

    def handle(self, *args, **options):
        album_ids = options["album_ids"]
        if album_ids:
            qs = models.Album.objects.filter(pk__in=album_ids)
        else:
            qs = models.Album.objects.all()

        total = qs.count()
        self.stdout.write(f"Rebuilding duration for {total} album(s)…")

        updated = 0
        batch_size = options["batch_size"]
        for i, album_id in enumerate(qs.values_list("pk", flat=True).iterator(), 1):
            models.Album.update_durations([album_id])
            updated += 1
            if i % batch_size == 0 or i == total:
                self.stdout.write(f"  {i}/{total}")

        self.stdout.write(self.style.SUCCESS(f"Updated {updated} album(s)."))
