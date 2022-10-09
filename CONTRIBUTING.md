# Contribute to Funkwhale's development

Thanks for your interest in contributing to Funkwhale! This document contains details on how to contribute to Funkwhale's codebase. If you'd like to contribute in other ways, check out our [contributor documentation](https://docs.funkwhale.audio).

```{contents}
:local:
:depth: 2
```

## Set up your development environment

There are several ways to set up your development environment depending on what you want to work on.

- Gitpod (recommended)
- Docker
- Vite (Frontend-only)

Follow the instructions in this guide to get set up.

### Gitpod

```{note}
You need a GitHub or GitLab.com account to log in to Gitpod.
```

Funkwhale has a Gitpod instance that gives you all the tools you need to work on Funkwhale's code. You can work on the code in-browser using a hosted VS Code install or open VS Code on your desktop over SSH.

You can open Gitpod directly by clicking the link below. This checks out the `develop` branch for you to work on directly.

[![Open in Gitpod](https://gitpod.io/button/open-in-gitpod.svg)](https://gitpod.io/#https://dev.funkwhale.audio/funkwhale/funkwhale)

If you want to work on a particular branch, commit, or merge request, you can do this straight from the GitLab interface. Select the arrow icon on the {guilabel}`Web IDE` button and select {guilabel}`Gitpod` to open Gitpod with the currently selected branch checked out.

![Select Gitpod as the default web IDE](/_static/images/select-gitpod-in-gitlab.png)

When you start Gitpod, it creates the following using the selected branch:

- A Funkwhale API instance
- A Funkwhale frontend instance

You can access the web app at `http://localhost:8000`. Log in with the following credentials:

- Username – `gitpod`
- Password – `gitpod`

#### Work on the frontend

By default, Gitpod spins up an entire Funkwhale stack. If you want to work only on the frontend:

1. Select `File` > `Open Folder`
2. Select `/workspace/funkwhale/front`

Gitpod starts a new Vite server on port 4000. This creates a frontend that isn't connected to any instance.

#### GitLab Workflow extension

Gitpod offers a GitLab workflow extension to help manage GitLab issues, merge requests, and pipelines. If you want to use it:

1. Navigate to the personal access token section of your [GitLab profile settings](https://dev.funkwhale.audio/-/profile/personal_access_tokens)
2. Create a personal access token with `api` and `read_user` scopes
3. Paste your token into your [Gitpod variables](https://gitpod.io/variables)

Use the following settings to automatically sign in to the extension with Gitpod. The `funkwhale/*` scope ensures you can use the settings for all Funkwhale-hosted projects.

```{list-table} Environment variables
:header-rows: 1

   * - Name
     - Value
     - Scope
   * - `GITLAB_WORKFLOW_INSTANCE_URL`
     - `https://dev.funkwhale.audio`
     - `funkwhale/*`
   * - `GITLAB_WORKFLOW_TOKEN`
     - Your token
     - `funkwhale/*`
```

#### Configure custom instance URL

You can configure Gitpod to use your Funkwhale pod as the default server. This means you can test frontend changes on your pod without selecting it each time. To do this, add the following to your [Gitpod variables](https://gitpod.io/variables):

```{list-table} Environment variables
   :header-rows: 1

   * - Name
     - Value
     - Scope
   * - `VUE_APP_INSTANCE_URL`
     - `https://funkwhale.example.com`
     - `funkwhale/funkwhale`
```

### Docker

Funkwhale can be run in Docker containers for local development. You can work on any part of the Funkwhale codebase and run the container setup to test your changes. To work with Docker:

1. [Install Docker](https://docs.docker.com/install)
2. [Install docker-compose](https://docs.docker.com/compose/install)
3. Clone the Funkwhale repository to your system. The `develop` branch is checked out by default

    ::::{tab-set}

    :::{tab-item} SSH

    ```sh
    git clone git@dev.funkwhale.audio/funkwhale/funkwhale.git
    cd funkwhale
    ```

    :::

    :::{tab-item} HTTPS

    ```sh
    git clone https://dev.funkwhale.audio/funkwhale/funkwhale.git
    cd funkwhale
    ```

    :::

    ::::

#### Set up your Docker environment

````{note}

Funkwhale provides a `dev.yml` file that contains the required docker-compose setup. You need to pass the `-f dev.yml` flag you run docker-compose commands to ensure it uses this file. If you don't want to add this each time, you can export it as a `COMPOSE_FILE` variable:

```sh
export COMPOSE_FILE=dev.yml
```

````

To set up your Docker environment:

1. Create a `.env` file to enable customization of your setup.

    ```sh
    touch .env
    ```

2. Add the following variables to load images and enable access to Django admin pages:

    ```text
    MEDIA_URL=http://localhost:8000/media/
    STATIC_URL=http://localhost:8000/staticfiles/
    ```

3. Create a network for federation support

    ```sh
    docker network create federation
    ```

Once you've set everything up, you need to build the containers. Run this command any time there are upstream changes or dependency changes to ensure you're up-to-date.

```sh
docker-compose -f dev.yml build
```

#### Set up the database

Funkwhale relies on a postgresql database to store information. To set this up, you need to run the `manage.py migrate` command:

```sh
docker-compose -f dev.yml run --rm api python manage.py migrate
```

This command creates all the required tables. You need to run this whenever there are changes to the API schema. You can run this at any time without causing issues.

#### Set up local data

You need to create some local data to mimic a production environment.

1. Create a superuser so you can log in to your local app:

    ```sh
    docker-compose -f dev.yml run --rm api pythong manage.py createsuperuser
    ```

2. Add some fake data to populate the database. The following command creates 25 artists with random albums, tracks, and metadata.

    ```sh
    artists=25 # Adds 25 fake artists
    command="from funkwhale_api.music import fake_data; fake_data.create_data($artists)"
    echo $command | docker-compose -f dev.yml run --rm -T api python manage.py shell -i python
    ```

#### Manage services

Once you have set up your containers, bring them up to start working on them.

1. Compile the translations:

    ```sh
    docker-compose -f dev.yml run --rm front yarn run i18n-compile
    ```

2. Launch all services:

    ```sh
    docker-compose -f dev.yml up front api nginx celeryworker
    ```

This gives you access to the following:

- The Funkwhale webapp on `http://localhost:8000`
- The Funkwhale API on `http://localhost:8000/api/v1`
- The Django admin interface on `http://localhost:8000/api/admin`

Once you're done with the containers, you can stop them all:

```sh
docker-compose -f dev.yml stop
```

If you want to destroy your containers, run the following:

```sh
docker-compose -f dev.yml down -v
```

#### Set up federation support

Working on federation features requires some additional setup. You need to do the following:

1. Update your DNS resolver to resolve all your .dev hostnames locally
2. Set up a reverse proxy (such as traefik) to catch .dev requests with a TLS certificate
3. Set up two or more local instances

To resolve hostnames locally, run the following:

::::{tab-set}

:::{tab-item} dnsmasq

```sh
echo "address=/test/172.17.0.1" | sudo tee /etc/dnsmasq.d/test.conf
sudo systemctl restart dnsmasq
```

:::

:::{tab-item} NetworkManager

```sh
echo "address=/test/172.17.0.1" | sudo tee /etc/NetworkManager/dnsmasq.d/test.conf
sudo systemctl restart NetworkManager
```

:::

::::

To add a wildcard certificate, copy the test certificate from the `docker/ssl` folder. This certificate is a wildcard for `*.funkwhale.test`

```sh
sudo cp docker/ssl/test.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

To run a reverse proxy for your app:

1. Add the following configuration to your `.env` file:

    ```text
    # Remove any port binding so you can specify this per-instance
    VUE_PORT_BINDING=
    # Disable certificate validation
    EXTERNAL_REQUESTS_VERIFY_SSL=false
    # Ensure all links use https
    FUNKWHALE_PROTOCOL=https
    # Disable host ports binding for the nginx container so that traefik handles everything
    NGINX_PORTS_MAPPING=80
    ```

2. Launch traefik using the bundled configuration:

    ```sh
    docker-compose -f docker/traefik.yml up -d
    ```

3. Set up as many different projects as you need. Make sure the `COMPOSE_PROJECT_NAME` and `VUE_PORT` variables are unique per instance

    ```sh
    export COMPOSE_PROJECT_NAME=node2
    export VUE_PORT=1234  # this has to be unique for each instance
    docker-compose -f dev.yml run --rm api python manage.py migrate
    docker-compose -f dev.yml run --rm api python manage.py createsuperuser
    docker-compose -f dev.yml up nginx api front nginx api celeryworker
    ```

You can access your project at `https://{COMPOSE_PROJECT_NAME}.funkwhale.test`.

### Vite

If you want to make changes to the frontend, you can use Vite to run a development server. This allows you to run a Funkwhale web app and see changes in real time

1. Clone the repository:

    ::::{tab-set}

    :::{tab-item} SSH

    ```sh
    git clone git@dev.funkwhale.audio/funkwhale/funkwhale.git
    cd funkwhale/front
    ```

    :::

    :::{tab-item} HTTPS

    ```sh
    git clone https://dev.funkwhale.audio/funkwhale/funkwhale.git
    cd funkwhale/front
    ```

    :::

    ::::

2. Install [Node.js](https://nodejs.org/en/download/package-manager/) and [Yarn](https://classic.yarnpkg.com/lang/en/docs/install/)
3. Install all dependencies:

    ```sh
    yarn install
    ```

4. Compile the translations:

    ```sh
    yarn i18n-compile
    ```

5. Launch the devlopment server:

    ```sh
    yarn dev
    ```

You can access the Funkwhale web app at `http://localhost:8000/front`. Connect this app to your pod by selecting {guilabel}`Switch instance` in the sidebar.

## Contribute to the API

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

### Write tests

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

We provide utilities and fixtures to make writing tests as easy as possible. You can see the list of available fixtures by running `docker-compose -f dev.yml run --rm api pytest --fixtures`.

#### Factories

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

#### Mocking

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

### Run tests

You can run all tests in the pytest suite with the following command:

```sh
docker-compose -f dev.yml run --rm api pytest
```

Run a specific test file by calling pytest against it:

```sh
docker-compose -f dev.yml run --rm api pytest tests/music/test_models.py
```

You can check the full list of options by passing the `-h` flag:

```sh
docker-compose -f dev.yml run --rm api pytest -h
```

## Contribute to the frontend

The Funkwhale frontend is a {abbr}`SPA (Single Page Application)` written in [Typescript](https://typescriptlang.org) and [Vue.js](https://vuejs.org).

### Styles

We currently use [Fomantic UI](https://fomantic-ui.com) as our UI framework. We customize this with our own SCSS files located in `front/src/styles/_main.scss`.

We apply changes to the Fomantic CSS files before we import them:

1. We replace hardcoded color values with CSS variables to make themin easier. For example: ``color: orange`` is replaced by ``color: var(--vibrant-color)``
2. We remove unused values from the CSS files to keep the size down

These changes are applied when you run `yarn install` through a `postinstall` hook. If you want to modify these changes, check the `front/scripts/fix-fomantic-css.py` script.

We plan to replace Fomantic with our own UI framework in the near future. Check our [Penpot](https://design.funkwhale.audio) to see what we've got planned.

### Components

Our [component library](https://ui.funkwhale.audio) contains reusable Vue components that you can add to the Funkwhale frontend. If you want to add a new component, check out [the repository](https://dev.funkwhale.audio/funkwhale/vui).

### Testing

The Funkwhale frontend contains some tests to catch errors before changes go live. The coverage is still fairly low, so we welcome any contributions.

To run the test suite, run the following command:

```sh
docker-compose -f dev.yml run --rm front yarn test:unit
```

To run tests as you make changes, launch the test suite with the `-w` flag:

```sh
docker-compose -f dev.yml run --rm front yarn test:unit -w
```

## Update UI copy

```{note}
Funkwhale is localized into several languages using [Weblate](https://translate.funkwhale.audio). You must make sure that any frontend strings are properly marked for localization. We use the [vue-i18n package](https://kazupon.github.io/vue-i18n/) to handle translation of frontend files.
```

All UI strings are stored in `front/locales/en.json` file. The file is structured to mimic the format of the repository. Each string should be labeled following the semantic naming for the item it applies to.

UI strings can be added to both the `<script>` and `<template>` part of a Vue file using following syntax:

::::{tab-set}

:::{tab-item} Locale file

```json
{
   "components": {
      "About": {
         "title": "About",
         "header": {
            "funkwhale": "A social platform to enjoy and share music"
         },
         "button": {
            "cancel": "Cancel"
         }
      }
   }
}
```

:::

:::{tab-item} Script

```typescript
import { useI18n } from 'vue-i18n'
//...
const { t } = useI18n()
//...
const labels = computed(() => ({
  title: t('components.About.title')
}))
```

:::

:::{tab-item} Template

```html
<h2>
    {{ $t('components.About.header.funkwhale') }}
</h2>
<button>
    {{ $t('components.About.button.cancel') }}
</button>
```

:::

::::

Some strings change depending on whether they are plural or not. You can create plural strings using the [vue-i18n pluralization syntax](https://kazupon.github.io/vue-i18n/guide/pluralization.html)

::::{tab-set}

:::{tab-item} Locale file

```json
"components": {
    "audio": {
        "ChannelCard": {
            "meta": {
                "episodes": "No episodes | {episode_count} episode | {episode_count} episodes",
                "tracks": "No tracks | {tracks_count} track | {tracks_count} tracks"
            }
        }
    }
}
```

:::

:::{tab-item} Template

```html
<div class="description">
<span
    v-if="object.artist?.content_category === 'podcast'"
    class="meta ellipsis"
>
    {{ $t('components.audio.ChannelCard.meta.episodes', {episode_count: object.artist.tracks_count}) }}
</span>
<span
    v-else
>
    {{ $t('components.audio.ChannelCard.meta.tracks', {tracks_count: object.artist?.tracks_count}) }}
</span>
<tags-list
    label-classes="tiny"
    :truncate-size="20"
    :limit="2"
    :show-more="false"
    :tags="object.artist?.tags ?? []"
/>
</div>
```

:::

::::

## Git workflow

Funkwhale uses GitLab's merge requests to manage changes. The workflow looks like this:

1. Assign the issue you are working on to yourself, or create one if it doesn't exist
2. Create a fork of the project
3. Check out the `develop` branch. If you're making a minor change (such as fixing a typo) you can check out the `stable` branch
4. Create a new branch based on the checked out branch. Make sure to give your branch a meaningful name and include the issue number if required
5. Work on your changes locally. Try to keep each commit small to make reviews easier
6. Add a changelog fragment summarizing your changes
7. Push your branch
8. Create a merge request in the GitLab frontend
9. We'll review your request and feed back

```{mermaid}
%%{init: { 'gitGraph': {'mainBranchName': 'stable'} } }%%
    gitGraph
        commit
        branch develop
        commit
        commit
        branch feature
        commit
        commit
        checkout develop
        merge feature
        commit
        checkout stable
        merge develop
```

## Changelog fragments

We try to add changelog fragments when we make changes so that we can show users what we've done. These fragments are small text files that contain a summary of changes. When we make a release, we compile these into a full changelog using [towncrier](https://pypi.org/project/towncrier/).

Each changelog fragment should contain a short and meaningful summary of changes and include the issue number (where applicable). For example:

```text
Fixed broken audio player on Chrome 42 for ogg files (#567)
```

If there's no issue, insert the merge request identifier instead:

```text
Fixed a typo in landing page copy (!342)
```

### Naming

Changelog fragments use the following naming convention: `changes/changelog.d/<name>.category>`. The `<name>` can be anything that describes your work, or the issue ID. The category can be one of the following:

- `feature` – a new feature
- `enhancement` – an extension of an existing feature
- `bugfix` – a bugfix or patch
- `doc` – new documentation
- `i18n` – internationalization-related work
- `misc` – any work that doesn't fit into the above categories

You can create these files manually or use the following snippet to create a fragment:

```sh
issue="42"
content="Fixed an overflowing issue on small resolutions (#$issue)"
category="bugfix"
echo "$content ($issue)" > changes/changelog.d/$issue.$category
```

## Make a release

Once we're ready to release a new version of the software, we can use the following process:

1. Export the new release version

    ```sh
    export NEXT_RELEASE=1.3.0
    ```

2. Export the previous release version

    ```sh
    export PREVIOUS_RELEASE=1.2.9
    ```

3. Pull the latest version of the `develop` branch. Use `stable` if you're releasing a bugfix.

    ::::{tab-set}

    :::{tab-item} Bugfix release
    :sync: bugfix

    ```sh
    git checkout stable
    git pull
    ```

    :::

    :::{tab-item} Feature release
    :sync: feature

    ```sh
    git checkout develop
    git pull
    ```

    :::

    ::::

4. Compile the changelog

    ```sh
    towncrier build --version $NEXT_RELEASE
    ```

5. Check the output and fix typos and mistakes
6. Add a list of contributors

    ```sh
    python3 scripts/get-contributions-stats.py $NEXT_RELEASE # Output a list of contributors
    git log $PREVIOUS_RELEASE.. --format="- %aN" --reverse | sort | uniq # Get a list of all commit authors
    nano CHANGELOG # Add these lists to the CHANGELOG
    ```

7. Update the `__version__` variable to the next release version

    ```sh
    nano api/funkwhale_api/__init__.py
    ```

8. Commit all changes

    ```sh
    git add .
    git commit -m "Version bump and changelog for $NEXT_RELEASE"
    ```

9. Create a tag

    ```sh
    git tag $NEXT_RELEASE
    ```

10. Publish the new tag to GitLab

    ```sh
    git push --tags && git push
    ```

11. Merge your changes into the alternate branch

    ::::{tab-set}

    :::{tab-item} Bugfix release
    :sync: bugfix

    ```sh
    git checkout develop && git merge stable && git push
    ```

    :::

    :::{tab-item} Feature release
    :sync: feature

    ```sh
    git checkout stable && git merge develop && git push
    ```

    :::

    ::::

Don't forget to create a blog post to announce the new release!
