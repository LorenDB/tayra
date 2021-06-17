Migrating to a New Server
=========================

Sometimes, it may be necessary or desirable to migrate your
existing Funkwhale setup to a new server. This can be helpful
if you need to boost resources or if you wish to use a different
hosting platform.

In this guide, the existing Funkwhale setup is called the origin server, and the new setup the destination server.

Requirements
------------

To get started with your new setup, you will need to have the
following:

- `rsync <https://linux.die.net/man/1/rsync>`_ installed on the **destination** server
- SSH access set up between the two servers

Non-Docker
----------

On the destination server, run through the :doc:`installation steps<../installation/debian>` with the exception of the following points:

- Do not enable the extensions ``unaccent`` and ``citext`` when setting up the database;
- Do not initialize the database by applying the migrate command;
- Do not create an admin account.

Stop all funkwhale related services on the destination server:

.. code-block:: shell

    sudo systemctl stop funkwhale.target

On the origin server, create a database backup:

.. code-block:: shell

    sudo -u funkwhale pg_dump -d funkwhale > "db.dump"

On the destination server, use rsync to fetch the contents of ``/srv/funwkhale/data/media/music/`` and ``/srv/funkwhale/data/media/`` from the origin server, as well as the database dump and the ``.env`` file:

.. code-block:: shell

    origin = <origin server IP/hostname>
    username = <your username>

    rsync -a $username@$origin:/srv/funkwhale/data/media/ /srv/funkwhale/data/media/
    rsync -a $username@$origin:/srv/funkwhale/data/music/ /srv/funkwhale/data/music/

    rsync -a $username@$origin:/srv/funkwhale/config/.env /srv/funkwhale/config/
    rsync -a $username@$origin:/srv/funkwhale/db.dump /srv/funkwhale/

On the destination server, restore the database dump:

.. code-block:: shell

    sudo psql -d funkwhale db.dump

Once the database has been restored, follow the database migration steps from the non-docker installation guide to complete the installation on the destination server.

Ensure that all DNS changes have been made and start the services:

.. code-block:: shell

    sudo systemctl start funkwhale.target

Docker
------

On the destination server, run through the :doc:`installation steps<../installation/docker>` but skip the ``docker-compose run --rm api python manage.py migrate`` step.

Stop all funkwhale related containers on the destination server.

On the origin server, create a database backup:

.. code-block:: shell

    docker exec -t funkwhale_postgres_1 pg_dumpall -c -U postgres > "db.dump"

On the destination server, use rsync to fetch the contents of ``/srv/funwkhale/data/media/music`` and ``/srv/funkwhale/data/media`` from the origin server, as well as the database dump nd the ``.env`` file:

.. code-block:: shell

    origin = <origin server IP/hostname>
    username = <your username>

    rsync -a $username@$origin:/srv/funkwhale/data/media/ /srv/funkwhale/data/media/
    rsync -a $username@$origin:/srv/funkwhale/data/music/ /srv/funkwhale/data/music/

    rsync -a $username@$origin:/srv/funkwhale/.env /srv/funkwhale/
    rsync -a $username@$origin:/srv/funkwhale/db.dump /srv/funkwhale/

Restore the database dump:

.. code-block:: shell

    docker exec -i funkwhale_postgres_1 pg_restore -c -U postgres -d postgres < "db.dump"

Once the database has been restored, run the migrations following the docker installation guide. 

Ensure that all DNS changes have been made and start the services.