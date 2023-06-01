import requests.exceptions
from django.core.management.base import BaseCommand, CommandError

from funkwhale_api.music import licenses


class Command(BaseCommand):
    help = "Check that specified licenses URLs are actually reachable"

    def handle(self, *args, **options):
        errored = []
        objs = licenses.LICENSES
        total = len(objs)
        for i, data in enumerate(objs):
            self.stderr.write("{}/{} Checking {}...".format(i + 1, total, data["code"]))
            response = requests.get(data["url"])
            try:
                response.raise_for_status()
            except requests.exceptions.RequestException:
                self.stderr.write("!!! Error while fetching {}!".format(data["code"]))
                errored.append((data, response))

        if errored:
            self.stdout.write(f"{len(errored)} licenses were not reachable!")
            for row, response in errored:
                self.stdout.write(
                    "- {}: error {} at url {}".format(
                        row["code"], response.status_code, row["url"]
                    )
                )

            raise CommandError()
        else:
            self.stdout.write("All licenses are valid and reachable :)")
