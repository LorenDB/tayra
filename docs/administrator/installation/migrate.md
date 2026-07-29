# Migrate to a new server

You can migrate your Funkwhale installation if you are setting up a new server. This can be useful if you are moving to a different hosting provider or upgrading your server.

In this guide we refer to your servers like this:

```{glossary}

Original server
   The server on which you are running Funkwhale.

Destination server
   The server to which you want to move your Funkwhale installation.
```

```{note}
Make sure you [back up your data](../upgrade/backup.md) before proceeding. This ensures you don't lose anything during the migration.
```

```{contents}
:local:
```

## Requirements

To get started with your new setup, you need to do the following:

- [Set up SSH access between both servers](https://kerneltalks.com/howto/establish-passwordless-ssh-between-two-servers/).
- Install [rsync](https://linux.die.net/man/1/rsync) on the {term}`destination server`.

## 1. Install Funkwhale on your destination server

Before you move your data, you need to install Funkwhale on your {term}`destination server`.

::::{tab-set}

:::{tab-item} Debian
:sync: debian

On your {term}`destination server`, follow the [installation guide](debian.md). Skip the following steps:

- Don't enable the `unaccent` and `citext` extensions when you set up the database.
- Don't run the `funkwhale-manage migrate` command to migrate the database.
- Don't create a superuser.

Once you have finished the installation, stop the Funkwhale services. These shouldn't be running when you copy your existing data over.

```{code-block} sh
sudo systemctl stop funkwhale.target
```

:::

:::{tab-item} Docker
:sync: docker

On your {term}`destination server`, follow the [installation guide](docker.md). Skip the following steps:

- Don't run the `funkwhale-manage migrate` command to migrate the database.
- Don't create a superuser.

Once you have finished the installation, stop the Funkwhale services. These shouldn't be running when you copy your existing data over.

```{code-block} sh
sudo docker compose stop
```

:::
::::

## 2. Create a database backup

You need to create a database backup on your {term}`original server` so that you can migrate your database. To do this, run the following command:

::::{tab-set}

:::{tab-item} Debian
:sync: debian

```{code-block} sh
sudo -u postgres -H pg_dump funkwhale > /srv/funkwhale/dump.sql
```

:::

:::{tab-item} Docker
:sync: docker

```{code-block} sh
sudo docker compose exec postgres pg_dumpall -c -U postgres > dump.sql
```

:::
::::

## 3. Copy files to your destination server

Next, you can copy your files from your {term}`original server` to your {term}`destination server`. You need to copy the following data:

- Your `.env` file.
- The database backup.
- The `/srv/funkwhale/data/media` directory.
- The `/srv/funkwhale/data/music` directory.

To do this:

1. Log in to your {term}`destination server`.
2. Export your server hostname or IP address and your user name on the server. In this example, the IP address is `123.123.123.123` and the username is `funkwhale`.

   ```{code-block} sh
   export ORIGIN="123.123.123.123"
   export USERNAME="funkwhale"
   ```

3. Use `rsync` to copy the information to your {term}`destination server`.

   ```{code-block} sh
   rsync -a $username@$origin:/srv/funkwhale/data/media/ /srv/funkwhale/data/media/ rsync -a #Copy the media folder
   $username@$origin:/srv/funkwhale/data/music/ /srv/funkwhale/data/music/  rsync -a  # Copy the music folder
   $username@$origin:/srv/funkwhale/config/.env /srv/funkwhale/config/ rsync -a  # Copy the .env file
   $username@$origin:/srv/funkwhale/dump.sql /srv/funkwhale/ # Copy your database backup
   ```

## 4. Restore your database backup

When you've copied everything to the {term}`destination server`, you need to import your database backup. To do this:

::::{tab-set}

:::{tab-item} Debian
:sync: debian

Run the following on your {term}`destination server`:

```{code-block} sh
sudo psql -d funkwhale dump.sql
```

When the import finishes, run the `funkwhale-manage migrate` command to set up the database.

```{code-block} sh
cd /srv/funkwhale
venv/bin/funkwhale-manage migrate
```

:::

:::{tab-item} Docker
:sync: docker

You need to initialize the postgres container on your {term}`destination server`. To do this:

1. Export the permissions and create an `init.sql` database dump.

   ```{code-block} sh
   echo "CREATE DATABASE "funkwhale" WITH ENCODING 'utf8'; \
   CREATE USER funkwhale; \
   GRANT ALL PRIVILEGES ON DATABASE funkwhale TO funkwhale;" > init.sql # Create an init.sql file with the correct permissions

   sudo docker compose run --rm postgres psql -U postgres -d postgres < "init.sql" # Import the init.sql file
   ```

2. Import your database backup.

   ```{code-block} sh
   sudo docker compose run --rm postgres psql -U postgres -d postgres < "dump.sql"
   ```

3. When the import finishes, run the `funkwhale-manage migrate` command to set up the database.

   ```{code-block} sh
   sudo docker compose run --rm api funkwhale-manage migrate
   ```

:::
::::

## 5. Check your DNS settings

Before you start Funkwhale on your {term}`destination server`, check your DNS changes have propagated. Once your hostname is pointing to your {term}`destination server's <destination server>` IP address, proceed to the next step.

## 6. Start your new Funkwhale installation

Once you confirm DNS points to your {term}`destination server`, start the Funkwhale services:

::::{tab-set}

:::{tab-item} Debian
:sync: debian

```{code-block} sh
sudo systemctl start funkwhale.target
```

:::

:::{tab-item} Docker
:sync: docker

```{code-block} sh
sudo docker compose up -d
```

:::
::::

That's it! You've migrated your Funkwhale instance to a new server.
