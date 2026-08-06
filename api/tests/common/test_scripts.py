import pytest

from funkwhale_api.common import scripts
from funkwhale_api.common.management.commands import script


@pytest.fixture
def command():
    return script.Command()


@pytest.mark.parametrize(
    "script_name",
    [
        "django_permissions_to_user_permissions",
        "test",
    ],
)
def test_script_command_list(command, script_name, mocker):
    mocked = mocker.patch(f"funkwhale_api.common.scripts.{script_name}.main")

    command.handle(script_name=script_name, interactive=False)

    mocked.assert_called_once_with(command, script_name=script_name, interactive=False)


@pytest.mark.parametrize(
    "open_api,expected_visibility", [(True, "everyone"), (False, "instance")]
)
def test_migrate_to_user_libraries_create_libraries(
    factories, open_api, expected_visibility, stdout
):
    user1 = factories["users.User"]()
    user2 = factories["users.User"]()

    result = scripts.migrate_to_user_libraries.create_libraries(open_api, stdout)

    user1_library = user1.libraries.get(
        name="default", privacy_level=expected_visibility
    )
    user2_library = user2.libraries.get(
        name="default", privacy_level=expected_visibility
    )

    assert result == {user1.pk: user1_library.pk, user2.pk: user2_library.pk}


def test_migrate_to_user_libraries_update_uploads(factories, stdout):
    user1 = factories["users.User"]()
    user2 = factories["users.User"]()

    library1 = factories["music.Library"](owner=user1)
    library2 = factories["music.Library"](owner=user2)

    upload1 = factories["music.Upload"]()
    upload2 = factories["music.Upload"]()

    # we delete libraries
    upload1.library = None
    upload2.library = None
    upload1.save()
    upload2.save()

    factories["music.ImportJob"](batch__submitted_by=user1, upload=upload1)
    factories["music.ImportJob"](batch__submitted_by=user2, upload=upload2)

    libraries_by_user = {user1.pk: library1.pk, user2.pk: library2.pk}

    scripts.migrate_to_user_libraries.update_uploads(libraries_by_user, stdout)

    upload1.refresh_from_db()
    upload2.refresh_from_db()

    assert upload1.library == library1
    assert upload1.import_status == "finished"
    assert upload2.library == library2
    assert upload2.import_status == "finished"


@pytest.mark.parametrize(
    "open_api,expected_visibility", [(True, "everyone"), (False, "instance")]
)
def test_migrate_to_user_libraries_without_jobs(
    factories, open_api, expected_visibility, stdout
):
    superuser = factories["users.User"](is_superuser=True)
    upload1 = factories["music.Upload"]()
    upload2 = factories["music.Upload"]()
    upload3 = factories["music.Upload"](audio_file=None)

    # we delete libraries
    upload1.library = None
    upload2.library = None
    upload3.library = None
    upload1.save()
    upload2.save()
    upload3.save()

    factories["music.ImportJob"](upload=upload2)
    scripts.migrate_to_user_libraries.update_orphan_uploads(open_api, stdout)

    upload1.refresh_from_db()
    upload2.refresh_from_db()
    upload3.refresh_from_db()

    superuser_library = superuser.libraries.get(
        name="default", privacy_level=expected_visibility
    )
    assert upload1.library == superuser_library
    assert upload1.import_status == "finished"
    # left untouched because they don't match filters
    assert upload2.library is None
    assert upload3.library is None


def test_migrate_to_users_libraries_command(
    preferences, mocker, db, command, queryset_equal_queries
):
    preferences["common__api_authentication_required"] = False
    open_api = not preferences["common__api_authentication_required"]
    create_libraries = mocker.patch.object(
        scripts.migrate_to_user_libraries,
        "create_libraries",
        return_value={"hello": "world"},
    )
    update_uploads = mocker.patch.object(
        scripts.migrate_to_user_libraries, "update_uploads"
    )
    update_orphan_uploads = mocker.patch.object(
        scripts.migrate_to_user_libraries, "update_orphan_uploads"
    )

    scripts.migrate_to_user_libraries.main(command)

    create_libraries.assert_called_once_with(open_api, command.stdout)
    update_uploads.assert_called_once_with({"hello": "world"}, command.stdout)
    update_orphan_uploads.assert_called_once_with(open_api, command.stdout)

