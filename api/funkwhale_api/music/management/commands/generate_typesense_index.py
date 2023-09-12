from django.core.management.base import BaseCommand

from funkwhale_api.typesense import tasks


class Command(BaseCommand):
    help = """
    Trigger the generation of a new typesense index for canonical Funkwhale tracks metadata.
    This is use to resolve Funkwhale tracks to MusicBrainz ids"""

    def handle(self, *args, **kwargs):
        tasks.build_canonical_index.delay()
        self.stdout.write("Tasks launched in celery worker.")
