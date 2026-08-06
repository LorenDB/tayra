"""
Migrate instance files to a library #463. For each user that imported music on an
instance, we will create a "default" library with related files and an instance-level
visibility (unless instance has common__api_authentication_required set to False,
in which case the libraries will be public).

Files without any import job will be bounded to a "default" library on the first
superuser account found.

"""

from funkwhale_api.common import preferences
from funkwhale_api.music import models
from funkwhale_api.users.models import User


def create_libraries(open_api, stdout):
    privacy_level = "everyone" if open_api else "instance"
    users = User.objects.all().only("pk")
    stdout.write("* Creating libraries with {} visibility".format(privacy_level))
    libraries_by_user = {}

    for user in users:
        library, created = models.Library.objects.get_or_create(
            name="default", owner=user, defaults={"privacy_level": privacy_level}
        )
        libraries_by_user[user.pk] = library.pk
        if created:
            stdout.write(f"  * Created library {library.pk} for user {user.pk}")
        else:
            stdout.write(
                "  * Found existing library {} for user {}".format(library.pk, user.pk)
            )

    return libraries_by_user


def update_uploads(libraries_by_user, stdout):
    stdout.write("* Updating uploads with proper libraries...")
    for user_id, library_id in libraries_by_user.items():
        jobs = models.ImportJob.objects.filter(
            upload__library=None, batch__submitted_by=user_id
        )
        candidates = models.Upload.objects.filter(
            pk__in=jobs.values_list("upload", flat=True)
        )
        total = candidates.update(library=library_id, import_status="finished")
        if total:
            stdout.write(f"  * Assigned {total} uploads to user {user_id}'s library")
        else:
            stdout.write(f"  * No uploads to assign to user {user_id}'s library")


def update_orphan_uploads(open_api, stdout):
    privacy_level = "everyone" if open_api else "instance"
    first_superuser = User.objects.filter(is_superuser=True).order_by("pk").first()
    if not first_superuser:
        stdout.write("* No superuser found, skipping update orphan uploads")
        return
    library, _ = models.Library.objects.get_or_create(
        name="default",
        owner=first_superuser,
        defaults={"privacy_level": privacy_level},
    )
    candidates = (
        models.Upload.objects.filter(library=None, jobs__isnull=True)
        .exclude(audio_file=None)
        .exclude(audio_file="")
    )

    total = candidates.update(library=library, import_status="finished")
    if total:
        stdout.write(
            "* Assigned {} orphaned uploads to superuser {}".format(
                total, first_superuser.pk
            )
        )
    else:
        stdout.write("* No orphaned uploads found")


def main(command, **kwargs):
    open_api = not preferences.get("common__api_authentication_required")
    libraries_by_user = create_libraries(open_api, command.stdout)
    update_uploads(libraries_by_user, command.stdout)
    update_orphan_uploads(open_api, command.stdout)
