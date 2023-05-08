# Upgrade your Docker Funkwhale installation

If you installed Funkwhale following the [Docker guide](../installation/docker.md), follow these steps to upgrade.

## Upgrade Funkwhale

1. SSH into your server
2. Log in as your `funkwhale` user.

   ```{code-block} sh
   su funkwhale
   ```

3. Navigate to your Funkwhale directory.

   ```{code-block} sh
   cd /srv/funkwhale
   ```

4. Export the Funkwhale version you want to update to. You'll use this in the rest of the commands in this guide.

   ```{parsed-literal}
   export FUNKWHALE_VERSION={sub-ref}`version`
   ```

5. Change the version number in your `.env` file. Update this to the same version number you exported in step 4.

   ```{code-block} sh
   nano .env
   ```

6. Log in as `su` to load the configuration from your `.env` file.

   ```{code-block} sh
   sudo su
   source .env
   ```

7. Pull the updated containers.

   ```{code-block} sh
   docker compose pull
   ```

8. Apply the database migrations.

   ```{code-block} sh
   docker compose run --rm api funkwhale-manage migrate
   ```

9. Relaunch your containers.

   ```{code-block} sh
   docker compose up -d
   ```

10. Exit the root shell.

```{code-block} sh
exit
```

That’s it! You’ve updated your Funkwhale pod. You should now see the new version running in your web browser.

## Update your reverse proxy configuration

To ensure your reverse proxy is up-to-date with changes, you should regenerate your Nginx configuration with each upgrade. To do this:

:::{include} /administrator/installation/docker.md
:start-after: Nginx update instructions
:end-before: Instructions end
:::

Once you've updated your configuration, reload Nginx.

```console
# systemctl reload nginx
```

## Upgrade the Postgres container

Funkwhale depends on Postgres for its database container. To upgrade Postgres, you need to export your database and import it into a new container to update the schema.

The following update methods are supported:

:::{contents}
:local:
:::

### Standard upgrade

To update your Postgres container, follow these steps:

1. Create a backup of your Funkwhale database. We will import this into the new postgres container later.

   ```console
   # docker compose exec -i postgres pg_dump -U postgres postgres > db_dump.sql
   ```

2. Stop all Funkwhale services

   ```console
   # docker compose down
   ```

3. Move the {file}`data/postgres` directory to another location to back it up

   ```console
   $ mv data/postgres data/postgres.bak
   ```

4. Create a new {file}`data/postgres` directory to house your data

   ```console
   $ mkdir data/postgres
   ```

5. Edit the {file}`docker-compose.yml` file in an editor of your choice.

   ```console
   $ nano docker-compose.yml
   ```

6. Update the version number in the `image` section of the `postgres` service to the major version you want to use. In this example, Postgres version `15` is used.

   {emphasize-lines="9"}

   ```yaml
   version: "3"

   services:
   postgres:
     restart: unless-stopped
     env_file: .env
     environment:
       - "POSTGRES_HOST_AUTH_METHOD=trust"
     image: postgres:15-alpine
     volumes:
       - ./data/postgres:/var/lib/postgresql/data
   ```

7. Save the file and close your editor

Once you've updated your Postgres containers, you need to migrate your database. To do this:

:::{include} /administrator/migration.md
:start-line: 112
:end-line: 129
:::

### Postgres upgrade container (AMD64 only)

You can use the [`postgres-upgrade`](https://hub.docker.com/r/tianon/postgres-upgrade/) container to upgrade Postgres on **AMD64** Docker deployments. This container automates the process of upgrading between major versions of Postgres. Use these commands to upgrade your Postgres container:

1. Export your current Postgres version number. You can find this in your `docker-compose.yml` file.

   ```console
   # export OLD_POSTGRES=13
   ```

2. Export the major version number you want to upgrade to.

   ```console
   # export NEW_POSTGRES=14
   ```

3. Stop the Postgres container. This means no data changes while you are upgrading.

   ```console
   # docker compose stop postgres
   ```

4. Run the migration using the `postgres-upgrade` container. This creates a new version of the database in the `/srv/funkwhale/data/postgres-new` directory.

   ```console
   # docker run --rm \
   -v $(pwd)/data/postgres:/var/lib/postgresql/${OLD_POSTGRES}/data \
   -v $(pwd)/data/postgres-new:/var/lib/postgresql/${NEW_POSTGRES}/data \
   tianon/postgres-upgrade:${OLD_POSTGRES}-to-${NEW_POSTGRES}
   ```

5. Re-add the access control rules required by Funkwhale.

   ```console
   # echo "host all all all trust" | tee -a ./data/postgres-new/pg_hba.conf
   ```

6. Swap your old database out with your new database.

   ```console
   # mv ./data/postgres ./data/postgres-old
   # mv ./data/postgres-new ./data/postgres
   ```

7. Pull the new Postgres version.

   ```console
   # docker compose pull
   ```

8. Restart your containers.

   ```console
   # docker compose up -d
   ```

That's it! Your Funkwhale pod is now running the new version of Postgres. The old database is available in `/srv/funkwhale/data/postgres-old`. You can back this up and remove it from your server once you've confirmed everything is working.
