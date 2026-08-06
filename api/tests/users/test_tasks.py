import pytest

from funkwhale_api.users import tasks


def test_delete_account(factories):
    user = factories["users.User"]()
    library = factories["music.Library"](owner=user)
    unrelated_library = factories["music.Library"]()

    tasks.delete_account(user_id=user.pk)

    with pytest.raises(user.DoesNotExist):
        user.refresh_from_db()

    with pytest.raises(library.DoesNotExist):
        library.refresh_from_db()

    # this one shouldn't be deleted
    unrelated_library.refresh_from_db()
