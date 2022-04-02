# Docker migration guide

Funkwhale used to offer two Docker-based installation methods. The multi-container method separates each services into its own container. The mono-container method kept all services into a single container.

The project deprecated the mono-container method as of Funkwhale 1.3.0. We decided not to continue supporting it for the following reasons:

1. It required a lot of maintenance when upgrading dependencies.
2. It offers no advantages over the multi-container method. Not separating the processes defeats the point of containerization.

Follow this guide to migrate a mono-container installation to a multi-container setup.

## Back up your Funkwhale directory

1. Before you begin, log in as your `funkwhale` user

   ```{code} bash
   sudo -u funkwhale -H bash
   ```

2. Create a full backup of your `/srv/funkwhale` directory.

   ```{code} bash
   cd /srv/
   cp funkwhale funkwhale.bak
   ```

3. Go to the original `/srv/funkwhale` folder to run the migration.

   ```{code} bash
   cd /srv/funkwhale
   ```

## Dump your Funkwhale database

1. Create a backup of your Funkwhale database. We will import this into the new postgres container later.

   ```{code} bash
   docker-compose exec funkwhale /usr/bin/pg_dumpall -U funkwhale > db_dump.sql
   ```

## Stop your Funkwhale instance

1. Stop all Funkwhale services. This ensures that no data is changed while you migrate your instance.

   ```{code} bash
   docker-compose down
   ```

## Prepare the multi-container setup

1. Export the Funkwhale version you want to install.

   ```{parsed-literal}
   export FUNKWHALE_VERSION={sub-ref}`version`
   ```

2. Download the required template files.

   ```{code} bash
   curl -L -o docker-compose.yml "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/${FUNKWHALE_VERSION}/deploy/docker-compose.yml"
   curl -L -o nginx/funkwhale.template "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/${FUNKWHALE_VERSION}/deploy/docker.nginx.template"
   curl -L -o nginx/funkwhale_proxy.conf "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/${FUNKWHALE_VERSION}/deploy/docker.funkwhale_proxy.conf"
   ```

## Update your instance env file

1. Take a backup of your current `.env` file.

   ```{code} bash
   mv .env .env.bak
   ```

2. Download the `.env` file template.

   ```{code} bash
   curl -L -o .env "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/${FUNKWHALE_VERSION}/deploy/env.prod.sample"
   ```

3. Change the permissions on your `.env` file.

   ```{code} bash
   chmod 600 .env
   ```

4. Replace the version number in your new `.env` file.

   ```{code} bash
   sed -i "s/FUNKWHALE_VERSION=latest/FUNKWHALE_VERSION=$FUNKWHALE_VERSION/" .env
   ```

5. Copy the settings from your old `.env` file to your new `.env` file. These will be added to the bottom of the file. Check the file and remove any duplicated settings after copying.

   ```{code} bash
   cat .env.bak >> .env
   ```

6. Update the database URL in your new `.env` file.

   ```{code} bash
   echo "DATABASE_URL=postgresql://funkwhale@postgres:5432/funkwhale" >> .env
   ```

## Migrate your database

1. Start up your new database container.

   ```{code} bash
   docker-compose up -d postgres
   ```

2. Import your database dump into the new container.

   ```{code} bash
   cat db_dump.sql | docker-compose exec -T postgres psql -U postgres
   ```

3. Run the database migrations.

   ```{code} bash
   docker-compose run --rm api python manage.py migrate
   ```

## Start your Funkwhale instance

Once you have imported your database and run migrations, you can start all containers.

   ```{code} bash
   docker-compose up -d
   ```
