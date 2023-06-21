import pathlib
from argparse import RawTextHelpFormatter

from django.core.management.base import BaseCommand
from django.db import transaction

from funkwhale_api.music import models


class Command(BaseCommand):
    help = """
    Update the reference for Uploads that have been imported with --in-place and are now moved to s3.

    Please note: This does not move any file! Make sure you already moved the files to your s3 bucket.

    Specify --source to filter the reference to update to files from a specific in-place directory. If no
    --source is given, all in-place imported track references will be updated.

    Specify --target to specify a subdirectory in the S3 bucket where you moved the files. If no --target is
    given, the file is expected to be stored in the same path as before.

    Examples:

    Music File: /music/Artist/Album/track.ogg
    --source: /music
    --target unset

    All files imported from /music will be updated and expected to be in the same folder structure in the bucket

    Music File: /music/Artist/Album/track.ogg
    --source: /music
    --target: /in_place

    The music file is expected to be stored in the bucket in the directory /in_place/Artist/Album/track.ogg
    """

    def create_parser(self, *args, **kwargs):
        parser = super().create_parser(*args, **kwargs)
        parser.formatter_class = RawTextHelpFormatter
        return parser

    def add_arguments(self, parser):
        parser.add_argument(
            "--no-dry-run",
            action="store_false",
            dest="dry_run",
            default=True,
            help="Disable dry run mode and apply updates for real on the database",
        )
        parser.add_argument(
            "--source",
            type=pathlib.Path,
            required=True,
            help="Specify the path of the directory where the files originally were stored to update their reference.",
        )
        parser.add_argument(
            "--target",
            type=pathlib.Path,
            help="Specify a subdirectory in the S3 bucket where you moved the files to.",
        )

    @transaction.atomic
    def handle(self, *args, **options):
        if options["dry_run"]:
            self.stdout.write("Dry-run on, will not touch the database")
        else:
            self.stdout.write("Dry-run off, *changing the database*")
        self.stdout.write("")

        prefix = f"file://{options['source']}"

        to_change = models.Upload.objects.filter(source__startswith=prefix)

        self.stdout.write(f"Found {to_change.count()} uploads to update.")

        target = options["target"] if options["target"] else options["source"]

        for upl in to_change:
            upl.audio_file = str(upl.source).replace(str(prefix), str(target))
            upl.source = None
            self.stdout.write(f"Upload expected in {upl.audio_file}")
            if not options["dry_run"]:
                upl.save()

        self.stdout.write("")
        if options["dry_run"]:
            self.stdout.write(
                "Nothing was updated, rerun this command with --no-dry-run to apply the changes"
            )
        else:
            self.stdout.write("Updating completed!")

        self.stdout.write("")
