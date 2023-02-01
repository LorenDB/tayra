# Contribute to the API

The Funkwhale API is the core of the Funkwhale ecosystem. It powers all actions in the Funkwhale app as well as other apps such as the CLI and mopidy plugin. The API is written in [Django rest framework](https://www.django-rest-framework.org/).

Before you start work on the API, you should open up a conversation in [the forum](https://forum.funkwhale.audio) to discuss the changes you want to make. All API changes need to be defined and scoped before code changes are made. If you are fixing a bug, you don't need to discuss this in the forum first.

Each API endpoint is made up of the following:

- Model – defines the shape of data and how it is stored in the database
- View – defines what data is reflected by an endpoint
- Serializer – defines how data is serialized and deserialized by the endpoint

The API directory is structured as follows:

- `config` – contains the project settings, URL structure, and web server gateway information setup
  - `settings` – contains all Django settings files
- `funkwhale_api` – contains the Funkwhale API logic
- `pyproject.toml` – contains the Python requirements
- `tests` – contains all tests. This directory matches the structure of the `funkwhale_api` directory

## Write tests

You should write tests to ensure that your code does what you expect it to. We use [pytest](https://pytest.org) and [factory-boy](https://factoryboy.readthedocs.io) to power our API testing suite.

Writing tests is outside the scope of this documentation, but here are some useful links to help you get started:

- [A quick introduction to writing unit tests with pytest](https://semaphoreci.com/community/tutorials/testing-python-applications-with-pytest)
- [A complete guide to Test-Driven Development](https://www.obeythetestinggoat.com/)
- [pytest documentation](https://docs.pytest.org/en/latest)
- [pytest-mock documentation](https://pypi.org/project/pytest-mock)
- [factory-boy documentation](http://factoryboy.readthedocs.io)

Try to keep your tests small and focused. Each test should test a single function, so if you need to test multiple things you should write multiple tests.

```{note}
Test files must target a module and follow the `funkwhale_api` directory structure. If you write tests for `funkwhale_api/myapp/views.py`, you should put them in `tests/myapp/test_views.py`.
```

We provide utilities and fixtures to make writing tests as easy as possible. You can see the list of available fixtures by running `sudo docker compose -f dev.yml run --rm api pytest --fixtures`.

### Factories

Each directory includes a `factories.py` file which contains factories for the models in the directory. You can use these to create arbitrary objects

```py
# funkwhale_api/myapp/users.py

def downgrade_user(user):
    """
    A simple function that remove superuser status from users
    and return True if user was actually downgraded
    """
    downgraded = user.is_superuser
    user.is_superuser = False
    user.save()
    return downgraded

# tests/myapp/test_users.py
from funkwhale_api.myapp import users

def test_downgrade_superuser(factories):
    user = factories['users.User'](is_superuser=True)
    downgraded = users.downgrade_user(user)

    assert downgraded is True
    assert user.is_superuser is False

def test_downgrade_normal_user_does_nothing(factories):
    user = factories['users.User'](is_superuser=False)
    downgraded = something.downgrade_user(user)

    assert downgraded is False
    assert user.is_superuser is False
```

### Mocking

Use mocks to fake logic in your tests. This is useful when testing components that depend on one another.

```py
# funkwhale_api/myapp/notifications.py

def notify(email, message):
    """
    A function that sends an e-mail to the given recipient
    with the given message
    """

    # our e-mail sending logic here
    # ...

# funkwhale_api/myapp/users.py
from . import notifications

def downgrade_user(user):
    """
    A simple function that remove superuser status from users
    and return True if user was actually downgraded
    """
    downgraded = user.is_superuser
    user.is_superuser = False
    user.save()
    if downgraded:
        notifications.notify(user.email, 'You have been downgraded!')
    return downgraded

# tests/myapp/test_users.py
def test_downgrade_superuser_sends_email(factories, mocker):
    """
    Your downgrade logic is already tested, however, we want to ensure
    an e-mail is sent when user is downgraded, but we don't have any e-mail
    server available in our testing environment. Thus, we need to mock
    the e-mail sending process.
    """
    mocked_notify = mocker.patch('funkwhale_api.myapp.notifications.notify')
    user = factories['users.User'](is_superuser=True)
    users.downgrade_user(user)

    # here, we ensure our notify function was called with proper arguments
    mocked_notify.assert_called_once_with(user.email, 'You have been downgraded')


def test_downgrade_not_superuser_skips_email(factories, mocker):
    mocked_notify = mocker.patch('funkwhale_api.myapp.notifications.notify')
    user = factories['users.User'](is_superuser=False)
    users.downgrade_user(user)

    # here, we ensure no e-mail was sent
    mocked_notify.assert_not_called()
```

## Run tests

You can run all tests in the pytest suite with the following command:

```sh
sudo docker compose -f dev.yml run --rm api pytest
```

Run a specific test file by calling pytest against it:

```sh
sudo docker compose -f dev.yml run --rm api pytest tests/music/test_models.py
```

You can check the full list of options by passing the `-h` flag:

```sh
sudo docker compose -f dev.yml run --rm api pytest -h
```
