from django.core.management.commands.migrate import Command as BaseCommand

from funkwhale_api.federation import factories
from funkwhale_api.federation.models import Actor


class Command(BaseCommand):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

        self.help = "Helper to generate randomized testdata"
        self.type_choices = {"notifications": self.handle_notifications}
        self.missing_args_message = f"Please specify one of the following sub-commands: { *self.type_choices.keys(), }"

    def add_arguments(self, parser):
        subparsers = parser.add_subparsers(dest="subcommand")

        notification_parser = subparsers.add_parser("notifications")
        notification_parser.add_argument(
            "username", type=str, help="Username to send the notifications to"
        )
        notification_parser.add_argument(
            "--count", type=int, help="Number of elements to create", default=1
        )

    def handle(self, *args, **options):
        self.type_choices[options["subcommand"]](options)

    def handle_notifications(self, options):
        self.stdout.write(
            f"Create {options['count']} notification(s) for {options['username']}"
        )
        try:
            actor = Actor.objects.get(preferred_username=options["username"])
        except Actor.DoesNotExist:
            self.stdout.write(
                "The user you want to create notifications for does not exist"
            )
            return

        follow_activity = factories.ActivityFactory(type="Follow")
        for _ in range(options["count"]):
            factories.InboxItemFactory(actor=actor, activity=follow_activity)
