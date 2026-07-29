from django.core.management.base import BaseCommand
from django.db import transaction

from funkwhale_api.music import models


class Command(BaseCommand):
    help = """
    This command makes it easy to prune all skipped Uploads from the database.
    Due to a bug they might caused the database to grow exponentially,
    especially when using in-place-imports on a regular basis. This command
    helps to clean up the database again.
    """

    def add_arguments(self, parser):
        parser.add_argument(
            "--force",
            default=False,
            help="Disable dry run mode and apply pruning for real on the database",
        )

    @transaction.atomic
    def handle(self, *args, **options):
        skipped = models.Upload.objects.filter(import_status="skipped")
        count = skipped.count()
        if options["force"]:
            skipped.delete()
            print(f"Deleted {count} entries from the database.")
            return

        print(
            f"Would delete {count} entries from the database.\
            Run with --force to actually apply changes to the database"
        )
