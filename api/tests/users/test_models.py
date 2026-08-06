import datetime

import pytest

from funkwhale_api.users import models


def test__str__(factories):
    user = factories["users.User"](username="hello")
    assert user.__str__() == "hello"


def test_get_permissions_superuser(factories):
    user = factories["users.User"](is_superuser=True)

    perms = user.get_permissions()
    for p in models.PERMISSIONS:
        assert perms[p] is True


def test_get_permissions_regular(factories):
    user = factories["users.User"](permission_library=True)

    perms = user.get_permissions()
    for p in models.PERMISSIONS:
        if p == "library":
            assert perms[p] is True
        else:
            assert perms[p] is False


def test_get_permissions_default(factories, preferences):
    preferences["users__default_permissions"] = ["library", "moderation"]
    user = factories["users.User"]()

    perms = user.get_permissions()
    assert perms["moderation"] is True
    assert perms["library"] is True
    assert perms["settings"] is False


@pytest.mark.parametrize(
    "args,perms,expected",
    [
        ({"is_superuser": True}, ["moderation", "library"], True),
        ({"is_superuser": False}, ["moderation"], False),
        ({"permission_library": True}, ["library"], True),
        ({"permission_library": True}, ["library", "moderation"], False),
    ],
)
def test_has_permissions_and(args, perms, expected, factories):
    user = factories["users.User"](**args)
    assert user.has_permissions(*perms, operator="and") is expected


@pytest.mark.parametrize(
    "args,perms,expected",
    [
        ({"is_superuser": True}, ["moderation", "library"], True),
        ({"is_superuser": False}, ["moderation"], False),
        ({"permission_library": True}, ["library", "moderation"], True),
        ({"permission_library": True}, ["moderation"], False),
    ],
)
def test_has_permissions_or(args, perms, expected, factories):
    user = factories["users.User"](**args)
    assert user.has_permissions(*perms, operator="or") is expected


def test_record_activity(factories, now):
    user = factories["users.User"]()
    assert user.last_activity is None

    user.record_activity()

    assert user.last_activity == now


def test_record_activity_does_nothing_if_already(factories, now, mocker):
    user = factories["users.User"](last_activity=now)
    save = mocker.patch("funkwhale_api.users.models.User.save")
    user.record_activity()

    save.assert_not_called()


def test_invitation_generates_random_code_on_save(factories):
    invitation = factories["users.Invitation"]()
    assert len(invitation.code) >= 6


def test_invitation_get_deleted_when_user_is_deleted(factories):
    invitation = factories["users.Invitation"](with_invited_user=True)
    invitation.invited_user.delete()

    assert models.Invitation.objects.count() == 0


def test_invitation_expires_after_delay(factories, settings):
    delay = settings.USERS_INVITATION_EXPIRATION_DAYS
    invitation = factories["users.Invitation"]()
    assert invitation.expiration_date == (
        invitation.creation_date + datetime.timedelta(days=delay)
    )


def test_can_filter_open_invitations(factories):
    okay = factories["users.Invitation"]()
    factories["users.Invitation"](expired=True)
    factories["users.User"](invited=True)

    assert models.Invitation.objects.count() == 3
    assert list(models.Invitation.objects.open()) == [okay]


def test_can_filter_closed_invitations(factories):
    factories["users.Invitation"]()
    expired = factories["users.Invitation"](expired=True)
    used = factories["users.User"](invited=True).invitation

    assert models.Invitation.objects.count() == 3
    assert list(models.Invitation.objects.order_by("id").open(False)) == [expired, used]


def test_get_channels_groups(factories):
    user = factories["users.User"](permission_library=True)

    assert user.get_channels_groups() == [
        f"user.{user.pk}.imports",
        f"user.{user.pk}.inbox",
        "admin.library",
    ]


@pytest.mark.parametrize(
    "default_quota, user_quota, expected",
    [(1000, None, 1000), (1000, 42, 42), (1000, 0, 0)],
)
def test_user_quota_set_on_user(
    default_quota, user_quota, expected, factories, preferences
):
    preferences["users__upload_quota"] = default_quota

    user = factories["users.User"](upload_quota=user_quota)
    assert user.get_upload_quota() == expected


def test_user_get_quota_status(factories, preferences):
    user = factories["users.User"](upload_quota=66)
    library = factories["music.Library"](owner=user)
    factories["music.Upload"](library=library, import_status="pending", size=1_000_000)
    factories["music.Upload"](library=library, import_status="skipped", size=2_000_000)
    factories["music.Upload"](library=library, import_status="errored", size=3_000_000)
    factories["music.Upload"](library=library, import_status="finished", size=4_000_000)
    factories["music.Upload"](library=library, import_status="draft", size=5_000_000)

    assert user.get_quota_status() == {
        "max": 66,
        "remaining": 51,
        "current": 15,
        "pending": 1,
        "skipped": 2,
        "errored": 3,
        "finished": 4,
        "draft": 5,
    }


def test_get_by_natural_key_annotates_primary_email_verified_no_email(factories):
    user = factories["users.User"]()
    user = models.User.objects.get_by_natural_key(user.username)

    assert user.has_verified_primary_email is False


def test_get_by_natural_key_annotates_primary_email_verified_true(factories):
    user = factories["users.User"](verified_email=True)
    user = models.User.objects.get_by_natural_key(user.username)

    assert user.has_verified_primary_email is True


def test_get_by_natural_key_annotates_primary_email_verified_false(factories):
    user = factories["users.User"](verified_email=False)
    user = models.User.objects.get_by_natural_key(user.username)

    assert user.has_verified_primary_email is False


def test_set_settings(factories):
    user = factories["users.User"]()
    assert user.settings is None

    user.set_settings(foo="bar", hello="world")

    user.refresh_from_db()
    assert user.settings == {
        "foo": "bar",
        "hello": "world",
    }
