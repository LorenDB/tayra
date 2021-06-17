Debian and Arch Linux installation
==================================

.. note::

    This guide targets Debian 10 (Buster), which is the latest version available, as well as Arch Linux.

Cache setup (Redis)
-------------------

Funkwhale requires a cache server:

- to make the whole system faster, by caching network requests or database queries;
- to handle asynchronous tasks such as music import.

On Debian-like distributions, a redis package is available, and you can
install it:

.. code-block:: shell

    sudo apt-get install redis-server

On Arch Linux and its derivatives:

.. code-block:: shell

    sudo pacman -S redis

This should be enough to have your redis server set up.

Install system dependencies
---------------------------

On Debian-like systems, you can install them using:

.. code-block:: shell

    sudo apt-get update
    # Install system dependencies
    sudo apt-get install curl python3-pip python3-venv git unzip libldap2-dev libsasl2-dev gettext-base zlib1g-dev libffi-dev libssl-dev

    # Funkwhale dependencies
    sudo apt install build-essential ffmpeg libjpeg-dev libmagic-dev libpq-dev postgresql-client python3-dev make

On Arch Linux and its derivatives:

.. code-block:: shell

    # Install system dependencies
    sudo pacman -S curl python-pip python-virtualenv git unzip

    # Funkwhale dependencies
    sudo pacman -S curl file ffmpeg libjpeg-turbo libpqxx python libldap libsasl

External Authentication (LDAP)
------------------------------

LDAP support requires some additional dependencies to enable. On the OS level both ``libldap2-dev`` and ``libsasl2-dev`` are required, and the Python modules ``python-ldap`` and ``python-django-auth-ldap`` must be installed. These dependencies are all included in the ``requirements.*`` files so deploying with those will install these dependencies by default. However, they are not required unless LDAP support is explicitly enabled. See :doc:`../admin/ldap` for more details.

Installation structure
----------------------

All Funkwhale-related files will be located under ``/srv/funkwhale`` apart
from database files and a few configuration files. We will also have a
dedicated ``funkwhale`` user to launch the processes we need and own those files.

You are free to use different values here, just remember to adapt those in the
next steps.

.. _create-funkwhale-user:

Create the user and the directory:

.. code-block:: shell

    sudo useradd -r -s /usr/sbin/nologin -d /srv/funkwhale -m funkwhale
    cd /srv/funkwhale

Log in as the newly created user from now on:

.. code-block:: shell

    sudo -u funkwhale -H bash

Now let's setup our directory layout. Here is how it will look like::

    .
    ├── config      # config / environment files
    ├── api         # api code of your instance
    ├── data        # persistent data, such as music files
    ├── front       # frontend files for the web user interface
    └── virtualenv  # python dependencies for Funkwhale

Create the aforementioned directories:

.. code-block:: shell

    mkdir -p config api data/static data/media data/music front

The ``virtualenv`` directory is a bit special and will be created separately.

Download the latest Funkwhale release
-------------------------------------

Funkwhale is splitted in two components:

1. The API, which will handle music storage and user accounts;
2. The frontend, that will simply connect to the API to interact with its data.

Those components are packaged in subsequent releases, such as 0.1, 0.2, etc.
You can browse the :doc:`changelog </changelog>` for a list of available releases
and pick the one you want to install, usually the latest one should be okay.

In this guide, we will assume you want to install the latest version of Funkwhale, which is |version|:

First, we will download the latest api release:

.. code-block:: shell

    curl -L -o "api-|version|.zip" "https://dev.funkwhale.audio/funkwhale/funkwhale/-/jobs/artifacts/|version|/download?job=build_api"
    unzip "api-|version|.zip" -d extracted
    mv extracted/api/* api/
    rm -rf extracted


Then we will download the frontend files:

.. code-block:: shell

    curl -L -o "front-|version|.zip" "https://dev.funkwhale.audio/funkwhale/funkwhale/-/jobs/artifacts/|version|/download?job=build_front"
    unzip "front-|version|.zip" -d extracted
    mv extracted/front .
    rm -rf extracted

.. note::

    You can also choose to get the code directly from the git repo. In this
    case, run::

        cd /srv

        rm -r funkwhale
        git clone -b master https://dev.funkwhale.audio/funkwhale/funkwhale funkwhale
        cd funkwhale

    The above clone command uses the master branch instead of the default develop branch, as master is stable and more suited for production setups.

    You'll also need to re-create the folders we make earlier::

        mkdir -p config data/static data/media data/music front

    You will still need to get the frontend files as specified before, because
    we're not going to build them.


You can leave the ZIP archives in the directory, this will help you know
which version you've installed next time you want to upgrade your installation.

Python dependencies
--------------------

Go back to the base directory:

.. code-block:: shell

    cd /srv/funkwhale

To avoid collisions with other software on your system, Python dependencies
will be installed in a dedicated
`virtualenv <https://docs.python.org/3/library/venv.html>`_.

First, create the virtualenv:

.. code-block:: shell

    python3 -m venv /srv/funkwhale/virtualenv

This will result in a ``virtualenv`` directory being created in
``/srv/funkwhale/virtualenv``.

In the rest of this guide, we'll need to activate this environment to ensure
dependencies are installed within it, and not directly on your host system. This is done with the following command:

.. code-block:: shell

    source /srv/funkwhale/virtualenv/bin/activate

Finally, install the python dependencies:

.. code-block:: shell

    pip install wheel
    pip install -r api/requirements.txt

.. important::

    Further commands involving python should always be run after you activated
    the virtualenv, as described earlier, otherwise those commands will raise
    errors


Environment file
----------------

You can now start to configure Funkwhale. The main way to achieve that is by
adding an environment file that will host settings that are relevant to your
installation.

Download the sample environment file:

.. parsed-literal::

    curl -L -o config/.env "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/master/deploy/env.prod.sample"

.. note::

    if you used git to get the latest version of the code earlier, you can instead do::

        cp /srv/funkwhale/deploy/env.prod.sample /srv/funkwhale/config/.env


Generate a secret key for Django::

    openssl rand -base64 45

You can then edit the file: the file is heavily commented, and the most relevant
configuration options are mentioned at the top of the file.

.. code-block:: shell

    chmod 600 /srv/funkwhale/config/.env  # reduce permissions on the .env file since it contains sensitive data
    nano /srv/funkwhale/config/.env

Paste the secret key you generated earlier at the entry
``DJANGO_SECRET_KEY`` and populate the ``DATABASE_URL``
and ``CACHE_URL`` values based on how you configured
your PostgreSQL and Redis servers in.

Database setup
--------------

Funkwhale requires a PostgreSQL database to work properly. Please refer
to the `PostgreSQL documentation <https://www.postgresql.org/download/>`_
for installation instructions specific to your os.

On Debian-like systems, you would install the database server like this:

.. code-block:: shell

    sudo apt-get install postgresql postgresql-contrib

On Arch Linux and its derivatives:

.. code-block:: shell

    sudo pacman -S postgresql

On Arch Linux, you'll also need to initialize the database. See `the Arch Linux wiki <https://wiki.archlinux.org/index.php/Postgresql#Initial_configuration>`_.

The remaining steps are heavily inspired from `this Digital Ocean guide <https://www.digitalocean.com/community/tutorials/how-to-set-up-django-with-postgres-nginx-and-gunicorn-on-ubuntu-16-04>`_.

Open a database shell:

.. code-block:: shell

    sudo -u postgres psql

Create the project database and user:

.. code-block:: shell

    CREATE DATABASE funkwhale WITH ENCODING 'utf8';
    CREATE USER funkwhale;
    GRANT ALL PRIVILEGES ON DATABASE funkwhale TO funkwhale;

.. warning::

    It's important that you use utf-8 encoding for your database,
    otherwise you'll end up with errors and crashes later on when dealing
    with music metadata that contains non-ascii chars.

Assuming you already have :ref:`created your funkwhale user <create-funkwhale-user>`,
you should now be able to open a postgresql shell:

.. code-block:: shell

    sudo -u funkwhale -H psql

Unless you give a superuser access to the database user, you should also
enable some extensions on your database server, as those are required
for Funkwhale to work properly:

.. code-block:: shell

    sudo -u postgres psql funkwhale -c 'CREATE EXTENSION "unaccent";'
    sudo -u postgres psql funkwhale -c 'CREATE EXTENSION "citext";'

Now that the database has been created, import the initial database structure using the virtualenv created before:

.. code-block:: shell

    python api/manage.py migrate

This will create the required tables and rows.

.. note::

    You can safely execute this command any time you want, this will only
    run unapplied migrations.

.. warning::

    You may sometimes get the following warning while applying migrations::

        "Your models have changes that are not yet reflected in a migration, and so won't be applied."

    This is a warning, not an error, and it can be safely ignored.
    Never run the ``makemigrations`` command yourself.

Create an admin account
-----------------------

Using the virtualenv created before, create your first user account:

.. code-block:: shell

    python api/manage.py createsuperuser

If you ever want to change a user's password from the command line, just run:

.. code-block:: shell

    python api/manage.py changepassword <user>

Collect static files
--------------------

Static files are the static assets used by the API server (icon PNGs, CSS, etc.).
We need to collect them explicitly, so they can be served by the webserver:

.. code-block:: shell

    python api/manage.py collectstatic

This should populate the directory you choose for the ``STATIC_ROOT`` variable
in your ``.env`` file.

Systemd unit file
------------------

.. note::

    All the command lines below should be executed as root.

Systemd offers a convenient way to manage your Funkwhale instance if you're
not using docker. We'll see how to setup systemd to properly start a Funkwhale instance.

First, download the sample unitfiles:

.. parsed-literal::

    sudo curl -L -o "/etc/systemd/system/funkwhale.target" "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/|version|/deploy/funkwhale.target"
    sudo curl -L -o "/etc/systemd/system/funkwhale-server.service" "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/|version|/deploy/funkwhale-server.service"
    sudo curl -L -o "/etc/systemd/system/funkwhale-worker.service" "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/|version|/deploy/funkwhale-worker.service"
    sudo curl -L -o "/etc/systemd/system/funkwhale-beat.service" "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/|version|/deploy/funkwhale-beat.service"

This will download three unitfiles:

- ``funkwhale-server.service`` to launch the Funkwhale web server;
- ``funkwhale-worker.service`` to launch the Funkwhale task worker;
- ``funkwhale-beat.service`` to launch the Funkwhale task beat (this is for recurring tasks);
- ``funkwhale.target`` to easily stop and start all of the services at once.

You can of course review and edit them to suit your deployment scenario
if needed, but the defaults should be fine.

Once the files are downloaded, reload systemd:

.. code-block:: shell

    sudo systemctl daemon-reload

And start the services:

.. code-block:: shell

    sudo systemctl start funkwhale.target

To ensure all Funkwhale processes are started automatically after a reboot, run:

.. code-block:: shell
    
    sudo systemctl enable funkwhale-server
    sudo systemctl enable funkwhale-worker
    sudo systemctl enable funkwhale-beat

You can check the statuses of all processes like this:

.. code-block:: shell

    sudo systemctl status funkwhale-\*

Reverse proxy setup
--------------------

See :ref:`Reverse proxy <reverse-proxy-setup>`.
