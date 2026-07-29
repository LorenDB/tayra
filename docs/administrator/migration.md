# Docker migration guide

Funkwhale used to offer two Docker-based installation methods. The multi-container method separates each services into its own container. The mono-container method kept all services into a single container.

The project deprecated the mono-container method as of Funkwhale 1.3.0. We decided not to continue supporting it for the following reasons:

1. It required a lot of maintenance when upgrading dependencies.
2. It offers no advantages over the multi-container method. Not separating the processes defeats the point of containerization.

Follow this guide to migrate a mono-container installation to a multi-container setup.

## Back up your Funkwhale directory

1. Before you begin, log in as your `funkwhale` user

   ```{code-block} sh
   sudo -u funkwhale -H bash
   ```

2. Create a full backup of your `/srv/funkwhale` directory.

   ```{code-block} sh
   cd /srv/
   sudo cp funkwhale funkwhale.bak
   ```

3. Go to the original `/srv/funkwhale` folder to run the migration.

   ```{code-block} sh
   cd /srv/funkwhale
   ```

## Dump your Funkwhale database

1. Create a backup of your Funkwhale database. We will import this into the new postgres container later.

   ```{code-block} sh
   sudo docker compose exec funkwhale /usr/bin/pg_dumpall -U funkwhale > db_dump.sql
   ```

## Stop your Funkwhale instance

1. Stop all Funkwhale services. This ensures that no data is changed while you migrate your instance.

   ```{code-block} sh
   sudo docker compose down
   ```

## Prepare the multi-container setup

1. Export the Funkwhale version you want to install.

   ```{parsed-literal}
   export FUNKWHALE_VERSION={sub-ref}`version`
   ```

2. Take a backup of your current `docker-compose.yml` file.

   ```{code-block} sh
   mv docker-compose.yml docker-compose.yml.bak
   ```

3. Download the required template files.

   ```{code-block} sh
   curl -L -o docker-compose.yml "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/${FUNKWHALE_VERSION}/deploy/docker-compose.yml"
   curl -L -o nginx/funkwhale.template "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/${FUNKWHALE_VERSION}/deploy/docker.nginx.template"
   curl -L -o nginx/funkwhale_proxy.conf "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/${FUNKWHALE_VERSION}/deploy/docker.funkwhale_proxy.conf"
   ```

## Update your instance env file

1. Take a backup of your current `.env` file.

   ```{code-block} sh
   mv .env .env.bak
   ```

2. Download the `.env` file template.

   ```{code-block} sh
   curl -L -o .env "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/${FUNKWHALE_VERSION}/deploy/env.prod.sample"
   ```

3. Change the permissions on your `.env` file.

   ```{code-block} sh
   chmod 600 .env
   ```

4. Replace the version number in your new `.env` file.

   ```{code-block} sh
   sed -i "s/FUNKWHALE_VERSION=latest/FUNKWHALE_VERSION=$FUNKWHALE_VERSION/" .env
   ```

5. Copy the settings from your old `.env` file to your new `.env` file.

   ```{code-block} sh
   cat .env.bak >> .env
   ```

Check the file and remove any duplicated settings after copying.

## Migrate your database

1. Start up your new database container.

   ```console
   # docker compose up -d postgres
   ```

2. Import your database dump into the new container.

   ```console
   # cat db_dump.sql | docker compose exec -T postgres psql -U postgres
   ```

3. Run the database migrations.

   ```console
   # docker compose run --rm api funkwhale-manage migrate
   ```

## Start your Funkwhale instance

Once you have imported your database and run migrations, you can start all containers.

```console
# docker compose up -d
```
