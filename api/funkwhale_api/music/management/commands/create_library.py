from django.core.management.base import BaseCommand

from funkwhale_api.federation.models import Actor
from funkwhale_api.music.models import Library


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
        actor, actor_created = Actor.objects.get_or_create(name=kwargs["username"])

        if actor_created:
            self.stdout.write("No existing actor found. New actor created.")

        library, created = Library.objects.get_or_create(
            name=kwargs["name"], actor=actor, privacy_level=kwargs["privacy_level"]
        )
        if created:
            self.stdout.write(
                "Created library {} for user {} with UUID {}".format(
                    library.pk, actor.user.pk, library.uuid
                )
            )
        else:
            self.stdout.write(
                "Found existing library {} for user {} with UUID {}".format(
                    library.pk, actor.user.pk, library.uuid
                )
            )
