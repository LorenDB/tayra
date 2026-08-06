import pytest

from funkwhale_api.common import filters


@pytest.mark.parametrize(
    "value, expected",
    [
        (True, True),
        ("True", True),
        ("true", True),
        ("1", True),
        ("yes", True),
        (False, False),
        ("False", False),
        ("false", False),
        ("0", False),
        ("no", False),
        ("None", None),
        ("none", None),
        ("Null", None),
        ("null", None),
    ],
)
def test_mutation_filter_is_approved(value, expected, factories):
    mutations = {
        True: factories["common.Mutation"](is_approved=True, payload={}),
        False: factories["common.Mutation"](is_approved=False, payload={}),
        None: factories["common.Mutation"](is_approved=None, payload={}),
    }

    qs = mutations[True].__class__.objects.all()

    filterset = filters.MutationFilter({"q": f"is_approved:{value}"}, queryset=qs)

    assert list(filterset.qs) == [mutations[expected]]


@pytest.mark.parametrize(
    "scope, user_index, expected_tracks",
    [
        ("me", 0, [0]),
        ("me", 1, [1]),
        ("me", 2, []),
        ("all", 0, [0, 1, 2, 3]),
        ("all", 1, [0, 1, 2, 3]),
        ("all", 2, [0, 1, 2, 3]),
        ("noop", 0, []),
        ("noop", 1, []),
        ("noop", 2, []),
        ("subscribed", 0, [3]),
        ("subscribed", 1, []),
        ("subscribed", 2, []),
        ("me,subscribed", 0, [0, 3]),
        ("me,subscribed", 1, [1]),
    ],
)
def test_actor_scope_filter(
    scope,
    user_index,
    expected_tracks,
    queryset_equal_list,
    factories,
    mocker,
    anonymous_user,
):
    user1 = factories["users.User"]()
    user2 = factories["users.User"]()
    users = [user1, user2, anonymous_user]
    followed_library = factories["music.Library"]()
    followed_channel = factories["audio.Channel"](
        library=followed_library, owner=user1
    )
    factories["audio.Subscription"](
        channel=followed_channel, user=user1, approved=True
    )
    tracks = [
        factories["music.Upload"](library__owner=user1, playable=True).track,
        factories["music.Upload"](library__owner=user2, playable=True).track,
        factories["music.Upload"](playable=True).track,
        factories["music.Upload"](playable=True, library=followed_library).track,
    ]

    class FS(filters.filters.FilterSet):
        scope = filters.ActorScopeFilter(
            user_field="uploads__library__owner",
            library_field="uploads__library",
            distinct=True,
        )

        class Meta:
            model = tracks[0].__class__
            fields = ["scope"]

    queryset = tracks[0].__class__.objects.all()
    request = mocker.Mock(user=users[user_index])
    filterset = FS({"scope": scope}, queryset=queryset.order_by("id"), request=request)

    expected = [tracks[i] for i in expected_tracks]

    assert filterset.qs == expected
