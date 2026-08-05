import pytest

from funkwhale_api.activity import utils
from funkwhale_api.common import fields


def test_get_activity(factories):
    user = factories["users.User"]()
    listening = factories["history.Listening"]()
    favorite = factories["favorites.TrackFavorite"]()

    objects = list(utils.get_activity(user))
    assert objects == [favorite, listening]


def test_get_activity_honors_privacy_level(factories, anonymous_user):
    factories["history.Listening"](user__privacy_level="me")
    favorite1 = factories["favorites.TrackFavorite"](user__privacy_level="everyone")
    factories["favorites.TrackFavorite"](user__privacy_level="instance")

    objects = list(utils.get_activity(anonymous_user))
    assert objects == [favorite1]


def test_get_activity_instance_visible_to_authenticated(factories):
    viewer = factories["users.User"](with_actor=True)
    factories["history.Listening"](user__privacy_level="me")
    visible = factories["favorites.TrackFavorite"](user__privacy_level="instance")
    factories["favorites.TrackFavorite"](user__privacy_level="me")

    objects = list(utils.get_activity(viewer))
    assert objects == [visible]


def test_get_activity_followers_visible_only_to_followers(factories):
    owner = factories["users.User"](privacy_level="followers", with_actor=True)
    follower = factories["users.User"](with_actor=True)
    stranger = factories["users.User"](with_actor=True)

    factories["federation.Follow"](
        actor=follower.actor, target=owner.actor, approved=True
    )
    favorite = factories["favorites.TrackFavorite"](user=owner)
    factories["history.Listening"](user=owner)

    follower_objects = list(utils.get_activity(follower))
    assert favorite in follower_objects
    assert len(follower_objects) == 2

    stranger_objects = list(utils.get_activity(stranger))
    assert stranger_objects == []

    owner_objects = list(utils.get_activity(owner))
    assert favorite in owner_objects
    assert len(owner_objects) == 2


def test_get_activity_followers_unapproved_follow_hidden(factories):
    owner = factories["users.User"](privacy_level="followers", with_actor=True)
    pending = factories["users.User"](with_actor=True)
    factories["federation.Follow"](
        actor=pending.actor, target=owner.actor, approved=False
    )
    factories["favorites.TrackFavorite"](user=owner)

    assert list(utils.get_activity(pending)) == []


@pytest.mark.parametrize(
    "level,anon_sees,auth_sees",
    [
        ("me", False, False),
        ("followers", False, False),
        ("instance", False, True),
        ("everyone", True, True),
    ],
)
def test_privacy_level_query_matrix_without_follow(
    factories, anonymous_user, level, anon_sees, auth_sees
):
    """Non-followers never see me/followers; instance needs auth; everyone is public."""
    owner = factories["users.User"](privacy_level=level, with_actor=True)
    stranger = factories["users.User"](with_actor=True)
    factories["history.Listening"](user=owner)

    from funkwhale_api.history.models import Listening

    anon_qs = Listening.objects.filter(
        fields.privacy_level_query(anonymous_user, "user__privacy_level")
    )
    auth_qs = Listening.objects.filter(
        fields.privacy_level_query(stranger, "user__privacy_level")
    )
    owner_qs = Listening.objects.filter(
        fields.privacy_level_query(owner, "user__privacy_level")
    )

    assert anon_qs.exists() is anon_sees
    assert auth_qs.exists() is auth_sees
    assert owner_qs.exists() is True
