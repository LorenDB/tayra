# Install Funkwhale using Docker

Funkwhale is available as a containerized application. This enables you to run each service in containers rather than install them on your server. You can run Funkwhale using [Docker](https://docker.com) and Docker-Compose.

```{note}
This guide assumes you are using a [Debian](https://debian.org)-based system.
```

```{contents}
:local:
```

## Before you begin

- Set a `FUNKWHALE_VERSION` variable to the version you want to install. You will use this version for all commands in this guide.

   ```{parsed-literal}
   export FUNKWHALE_VERSION={sub-ref}`version`
   ```

- Install [Docker](https://docs.docker.com/engine/install/) and [Docker Compose](https://docs.docker.com/compose/install/).
- Install `curl`.

   ```{code} bash
   sudo apt update # update apt cache
   sudo apt install curl
   ```

## 1. Download the project files

1. Create the project directory structure.

   ```{code} bash
   mkdir /srv/funkwhale /srv/funkwhale/nginx
   ```

2. Navigate to the project directory

   ```{code} bash
   cd /srv/funkwhale
   ```

3. Download the `docker-compose` template. This contains information about the containers and how they work together.

   ```{code} bash
   curl -L -o /srv/funkwhale/docker-compose.yml "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/${FUNKWHALE_VERSION}/deploy/docker-compose.yml"
   ```

4. Download the nginx templates. You need these to set up your reverse proxy.

   ```{code} bash
   curl -L -o /srv/funkwhale/nginx/funkwhale.template "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/${FUNKWHALE_VERSION}/deploy/docker.nginx.template"
   curl -L -o /srv/funkwhale/nginx/funkwhale_proxy.conf "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/${FUNKWHALE_VERSION}/deploy/docker.funkwhale_proxy.conf"
   ```

That's it! You've set up your project files. The directory structure looks like this:

```{code}
.
├── docker-compose.yml
└── nginx
    ├── funkwhale_proxy.conf
    └── funkwhale.template
```

## 2. Set up your environment file

The environment file contains options you can use to control your Funkwhale pod. Follow these steps to get a working environment up and running.

1. Download the `.env` template to your `/srv/funkwhale` directory.

   ```{code} bash
   curl -L -o /srv/funkwhale/.env "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/${FUNKWHALE_VERSION}/deploy/env.prod.sample"
   ```

2. Update `FUNKWHALE_VERSION` in the `.env` file to the `$FUNKWHALE_VERSION` variable you set earlier.

   ```{code} bash
   sed -i "s/FUNKWHALE_VERSION=latest/FUNKWHALE_VERSION=$FUNKWHALE_VERSION/" .env
   ```

3. Reduce the permissions on your `.env` file to `600`. This means that only your user can read and write this file.

   ```{code} bash
   chmod 600 /srv/funkwhale/.env
   ```

4. Generate a secret key for Django. This keeps your Funkwhale data secure. Do not share this key with anybody.

   ```{code} bash
   openssl rand -base64 45
   ```

5. Open the `.env` file in a text editor. For this example, we will use `nano`.

   ```{code} bash
   nano /srv/funkwhale/.env
   ```

6. Update the following settings:
    - Paste the secret key in the `DJANGO_SECRET_KEY` field.
    - Populate the `FUNKWHALE_HOSTNAME` field with the URL of your server.

7. Hit {kbd}`ctrl + x` then {kbd}`y` to save the file and close `nano`.

You're done! Your environment file is now ready to go. You can check out a full list of configuration options in our Environment file guide.

## 3. Set up Funkwhale

Once you've filled in your environment file, you can set up Funkwhale. Follow these steps to create your database and create a superuser.

1. Pull the containers to download all the required services.

   ```{code} bash
   cd /srv/funkwhale
   docker-compose pull
   ```

2. Bring up the database container so you can run the database migrations.

   ```{code} bash
   docker-compose up -d postgres
   ```

3. Run the database migrations.

   ```{code} bash
   docker-compose run --rm api python manage.py migrate
   ```

   ````{note}
   You may see the following warning when applying migrations:

      ```{code}
      "Your models have changes that are not yet reflected in a migration, and so won't be applied."
      ```

   You can safely ignore this warning.
   ````

4. Create your superuser.

   ```{code} bash
   docker-compose run --rm api python manage.py createsuperuser
   ```

5. Launch all the containers to bring up your pod.

   ```{code} bash
   docker-compose up -d
   ```

That's it! Your Funkwhale pod is now up and running.

## 4. Set up your reverse proxy

Funkwhale uses a reverse proxy to serve content to users. We use [Nginx](https://nginx.com) to serve this proxy. Follow this guide to install an Nginx configuration using details from your `.env` file.

1. Install Nginx.

   ```{code} bash
   sudo apt-get update
   sudo apt-get install nginx
   ```

2. Download the Nginx templates from Funkwhale.

   ```{code} bash
   sudo curl -L -o /etc/nginx/funkwhale_proxy.conf "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/$FUNKWHALE_VERSION/deploy/funkwhale_proxy.conf"
   sudo curl -L -o /etc/nginx/sites-available/funkwhale.template "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/$FUNKWHALE_VERSION/deploy/docker.proxy.template"
   ```

3. Create an Nginx template with details from your `.env` file.

   ```{code} bash
   # Log in to a root shell.

   sudo su
   
   # Create an Nginx configuration using the Funkwhale template with details from your `.env` file.

   set -a && source /srv/funkwhale/.env && set +a
   envsubst "`env | awk -F = '{printf \" $%s\", $$1}'`" \
      < /etc/nginx/sites-available/funkwhale.template \
      > /etc/nginx/sites-available/funkwhale.conf

   # Enable the configuration so that Nginx serves it.

   ln -s /etc/nginx/sites-available/funkwhale.conf /etc/nginx/sites-enabled/

   # Exit the root shell.

   exit
   ```

That's it! You've created your Nginx file. Run the following command to check the `.env` details populated correctly.

```{code} bash
grep '${' /etc/nginx/sites-enabled/funkwhale.conf
```
