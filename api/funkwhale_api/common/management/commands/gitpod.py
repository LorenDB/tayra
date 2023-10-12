import os

import debugpy
import uvicorn
from django.core.management import call_command
from django.core.management.commands.migrate import Command as BaseCommand

from funkwhale_api.common import preferences
from funkwhale_api.music.models import Library
from funkwhale_api.users.models import User


class Command(BaseCommand):
    help = "Manage gitpod environment"

    def add_arguments(self, parser):
        parser.add_argument("command", nargs="?", type=str)

    def handle(self, *args, **options):
        command = options["command"]

        if not command:
            return self.show_help()

        if command == "init":
            return self.init()

        if command == "dev":
            return self.dev()

    def show_help(self):
        self.stdout.write("")
        self.stdout.write("Available commands:")
        self.stdout.write("init - Initialize gitpod workspace")
        self.stdout.write("dev - Run Funkwhale in development mode with debug server")
        self.stdout.write("")

    def init(self):
        user = User.objects.get(username="gitpod")

        # Allow anonymous access
        preferences.set("common__api_authentication_required", False)

        # Download music catalog
        os.system(
            "git clone https://dev.funkwhale.audio/funkwhale/catalog.git /tmp/catalog"
        )
        os.system("mv -f /tmp/catalog/music /workspace/funkwhale/data")
        os.system("rm -rf /tmp/catalog/music")

        # Import music catalog into library
        call_command(
            "create_library",
            "gitpod",
            name="funkwhale/catalog",
            privacy_level="everyone",
        )
        call_command(
            "import_files",
            Library.objects.get(actor=user.actor).uuid,
            "/workspace/funkwhale/data/music/",
            recursive=True,
            in_place=True,
            no_input=False,
        )

    def dev(self):
        debugpy.listen(5678)
        uvicorn.run(
            "config.asgi:application",
            host="0.0.0.0",
            port=5000,
            reload=True,
            reload_dirs=[
                "/workspace/funkwhale/api/config/",
                "/workspace/funkwhale/api/funkwhale_api/",
            ],
        )
