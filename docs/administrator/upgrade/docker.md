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

## Upgrade the postgres container

Funkwhale depends on postgres for its database container. To upgrade postgres, you need to export your database and import it into the new container.

To upgrade postgres on Docker we use the [`postgres-upgrade`](https://hub.docker.com/r/tianon/postgres-upgrade/) container. This Docker container automates the process of upgrading between major versions of postgres. Use these commands to upgrade your postgres container:

1. Export your current postgres version number. You can find this in your `docker-compose.yml` file.

   ```{code-block} sh
   export OLD_POSTGRES=13
   ```

2. Export the major version number you want to upgrade to.

   ```{code-block} sh
   export NEW_POSTGRES=14
   ```

3. Stop the postgres container. This means no data changes while you are upgrading.

   ```{code-block} sh
   sudo docker compose stop postgres
   ```

4. Run the migration using the `postgres-upgrade` container. This creates a new version of the database in the `/srv/funkwhale/data/postgres-new` directory.

   ```{code-block} sh
   sudo -E docker run --rm \
   -v $(pwd)/data/postgres:/var/lib/postgresql/${OLD_POSTGRES}/data \
   -v $(pwd)/data/postgres-new:/var/lib/postgresql/${NEW_POSTGRES}/data \
   tianon/postgres-upgrade:${OLD_POSTGRES}-to-${NEW_POSTGRES}
   ```

5. Re-add the access control rules required by Funkwhale.

   ```{code-block} sh
   echo "host all all all trust" | sudo tee -a ./data/postgres-new/pg_hba.conf
   ```

6. Swap your old database out with your new database.

   ```{code-block} sh
   mv ./data/postgres ./data/postgres-old
   mv ./data/postgres-new ./data/postgres
   ```

7. Pull the new postgres version.

   ```{code-block} sh
   sudo docker compose pull
   ```

8. Restart your containers.

   ```{code-block} sh
   sudo docker compose up -d
   ```

That's it! Your Funkwhale pod is now running the new version of postgres. The old database is available in `/srv/funkwhale/data/postgres-old`. You can back this up and remove it from your server once you've confirmed everything is working.
