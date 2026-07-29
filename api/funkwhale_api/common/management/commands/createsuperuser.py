import os

from django.contrib.auth.management.commands.createsuperuser import (
    Command as BaseCommand,
)
from django.core.management.base import CommandError


class Command(BaseCommand):
    def handle(self, *apps_label, **options):
        """
        Creating Django Superusers would bypass some of our username checks, which can lead to unexpected behaviour.
        We therefore prohibit the execution of the command.
        """
        if not os.environ.get("FORCE") == "1":
            raise CommandError(
                "Running createsuperuser on your Funkwhale instance bypasses some of our checks "
                "which can lead to unexpected behavior of your instance. We therefore suggest to "
                "run `funkwhale-manage fw users create --superuser` instead."
            )

        return super().handle(*apps_label, **options)
