from django.core.management.base import BaseCommand

from funkwhale_api.music.models import Library
from funkwhale_api.users.models import User


class Command(BaseCommand):
    help = """
    Create a new library for a given user.
    """

    def add_arguments(self, parser):
        parser.add_argument(
            "username",
            type=str,
            help=("Specify the owner of the library to be created."),
        )
        parser.add_argument(
            "--name",
            type=str,
            help=("Specify a name for the library."),
            default="default",
        )
        parser.add_argument(
            "--privacy-level",
            type=str.lower,
            choices=["me", "instance", "everyone"],
            help=("Specify the privacy level for the library."),
            default="me",
        )

    def handle(self, *args, **kwargs):
        user, user_created = User.objects.get_or_create(username=kwargs["username"])

        if user_created:
            self.stdout.write("No existing user found. New user created.")

        library, created = Library.objects.get_or_create(
            name=kwargs["name"], owner=user, privacy_level=kwargs["privacy_level"]
        )
        if created:
            self.stdout.write(
                "Created library {} for user {} with UUID {}".format(
                    library.pk, user.pk, library.uuid
                )
            )
        else:
            self.stdout.write(
                "Found existing library {} for user {} with UUID {}".format(
                    library.pk, user.pk, library.uuid
                )
            )
