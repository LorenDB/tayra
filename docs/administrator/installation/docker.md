# Install Funkwhale using Docker

Funkwhale is available as a containerized application. This enables you to run each service in containers rather than install them on your server. You can run Funkwhale using [Docker](https://docker.com).

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

- Install [Docker](https://docs.docker.com/engine/install/) and the [compose plugin](https://docs.docker.com/compose/install/linux/#install-using-the-repository).
- Install `curl`.

  ```{code-block} sh
  sudo apt update # update apt cache
  sudo apt install curl
  ```

## 1. Create a Funkwhale user

It's good practice to create a user on your server for Funkwhale administration. Doing this makes it easy to make sure you're running commands from the right place. Follow these steps to set up your user.

1. Create the `funkwhale` user and set its shell to `bash` and its home directory to `/srv/funkwhale`.

   ```{code-block} sh
   sudo useradd --system --shell /bin/bash --create-home --home-dir /srv/funkwhale funkwhale
   ```

````{note}
To perform any tasks as the `funkwhale` user, prefix your commands with `sudo -u funkwhale`.

```{code-block} sh
sudo -u funkwhale <command>
```

Or log in as `funkwhale` with `sudo su funkwhale` before running your commands.

```{code-block} sh
sudo su funkwhale
<command>
```
````

That's it! You've created your `funkwhale` user.

## 2. Download the project files

1. Create the project directory structure.

   ```{code-block} sh
   mkdir /srv/funkwhale /srv/funkwhale/nginx
   ```

2. Navigate to the project directory

   ```{code-block} sh
   cd /srv/funkwhale
   ```

3. Download the `docker compose` template. This contains information about the containers and how they work together.

   ```{code-block} sh
   curl -L -o /srv/funkwhale/docker-compose.yml "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/${FUNKWHALE_VERSION}/deploy/docker-compose.yml"
   ```

That's it! You've set up your project files.

## 3. Set up your environment file

The environment file contains options you can use to control your Funkwhale pod. Follow these steps to get a working environment up and running.

1. Download the `.env` template to your `/srv/funkwhale` directory.

   ```{code-block} sh
   curl -L -o /srv/funkwhale/.env "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/${FUNKWHALE_VERSION}/deploy/env.prod.sample"
   ```

2. Update `FUNKWHALE_VERSION` in the `.env` file to the `$FUNKWHALE_VERSION` variable you set earlier.

   ```{code-block} sh
   sed -i "s/FUNKWHALE_VERSION=latest/FUNKWHALE_VERSION=$FUNKWHALE_VERSION/" .env
   ```

3. Reduce the permissions on your `.env` file to `600`. This means that only your user can read and write this file.

   ```{code-block} sh
   chmod 600 /srv/funkwhale/.env
   ```

4. Generate a secret key for Django. This keeps your Funkwhale data secure. Do not share this key with anybody.

   ```{code-block} sh
   openssl rand -base64 45
   ```

5. Open the `.env` file in a text editor. For this example, we will use `nano`.

   ```{code-block} sh
   nano /srv/funkwhale/.env
   ```

6. Update the following settings:

   - Paste the secret key in the `DJANGO_SECRET_KEY` field.
   - Populate the `FUNKWHALE_HOSTNAME` field with the URL of your server.

7. Hit {kbd}`ctrl + x` then {kbd}`y` to save the file and close `nano`.

You're done! Your environment file is now ready to go. You can check out a full list of configuration options in our Environment file guide.

## 4. Set up Funkwhale

Once you've filled in your environment file, you can set up Funkwhale. Follow these steps to create your database and create a superuser.

1. Pull the containers to download all the required services.

   ```{code-block} sh
   cd /srv/funkwhale
   sudo docker compose pull
   ```

2. Bring up the database container so you can run the database migrations.

   ```{code-block} sh
   sudo docker compose up -d postgres
   ```

3. Run the database migrations.

   ```{code-block} sh
   sudo docker compose run --rm api funkwhale-manage migrate
   ```

   ````{note}
   You may see the following warning when applying migrations:

      ```{code-block} text
      "Your models have changes that are not yet reflected in a migration, and so won't be applied."
      ```

   You can safely ignore this warning.
   ````

4. Create your superuser.

   ```{code-block} sh
   sudo docker compose run --rm api funkwhale-manage createsuperuser
   ```

5. Launch all the containers to bring up your pod.

   ```{code-block} sh
   sudo docker compose up -d
   ```

That's it! Your Funkwhale pod is now up and running.

## 5. Set up your reverse proxy

Funkwhale requires a reverse proxy to serve content to users. We recommend using [Nginx](https://nginx.com) to handle requests to your container. Follow this guide to install an Nginx configuration using details from your `.env` file.

:::{note} Before you begin
Nginx isn't preinstalled on Debian. You can install it by running the following commands:

```console
$ sudo apt update
$ sudo apt install nginx
```

:::

% Nginx update instructions

1. Log in to a root shell to make changes to the config files

   ```console
   $ sudo su
   ```

2. Download the new Nginx templates from Funkwhale

   ```console
   # curl -L -o /etc/nginx/funkwhale_proxy.conf "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/$FUNKWHALE_VERSION/deploy/funkwhale_proxy.conf"
   # curl -L -o /etc/nginx/sites-available/funkwhale.template "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/$FUNKWHALE_VERSION/deploy/docker.proxy.template"
   ```

3. Update the Nginx configuration with details from your {file}`.env` file

   ```console
   # set -a && source /srv/funkwhale/config/.env && set +a
   envsubst "`env | awk -F = '{printf \" $%s\", $$1}'`" \
      < /etc/nginx/sites-available/funkwhale.template \
      > /etc/nginx/sites-available/funkwhale.conf
   ```

4. Check the configuration file to make sure the template values have been updated properly

   ```console
   # grep '${' /etc/nginx/sites-available/funkwhale.conf
   ```

% Instructions end

5. Create a symbolic link to the {file}`sites-enabled` directory to enable your configuration

   ```console
   # ln -s /etc/nginx/sites-available/funkwhale.conf /etc/nginx/sites-enabled/
   ```

6. Restart Nginx

   ```console
   # systemctl restart nginx
   ```

That's it! You've created your Nginx file.

### Override default Nginx templates

The frontend container ships default Nginx templates which serve content to the reverse proxy. These files read variables from your `.env` file to correctly serve content. In some cases, you might want to override these defaults. To do this:

1. Create a `/srv/funkwhale/nginx` directory to house your files.

   ```{code-block} sh
   mkdir /srv/funkwhale/nginx
   ```

2. Download the Nginx template files to the `/srv/funkwhale/nginx` directory.

   ```{code-block} sh
   curl -L -o /srv/funkwhale/nginx/funkwhale.template "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/${FUNKWHALE_VERSION}/deploy/docker.nginx.template"
   curl -L -o /srv/funkwhale/nginx/funkwhale_proxy.conf "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/${FUNKWHALE_VERSION}/deploy/docker.funkwhale_proxy.conf"
   ```

3. Make any changes you want to make to these files.
4. Open your `docker-compose.yml` file in a text editor. For this example, we will use `nano`.

   ```{code-block} sh
   nano /srv/funkwhale/docker-compose.yml
   ```

5. Uncomment the lines in the `volumes` section of the `front` service by deleting the `#` in front of them.

   ```{code-block} yaml
   version: "3"
   services:
      front:
         volumes:
            # Uncomment if you want to use your previous nginx config, please let us
            # know what special configuration you need, so we can support it with out
            # upstream nginx configuration!
            - "./nginx/funkwhale.template:/etc/nginx/conf.d/funkwhale.template:ro"
            - "./nginx/funkwhale_proxy.conf:/etc/nginx/funkwhale_proxy.conf:ro"
   ```

6. Bring the `front` container up again to pick up the changes.

   ```{code-block} sh
   sudo docker compose up -d front
   ```

That's it! The container mounts your custom nginx files and uses its values to serve Funkwhale content. To revert to the default values, comment out the volumes by adding a `#` in front of them and bring the `front` container back up.

## 6. Set up TLS

To enable your users to connect to your pod securely, you need to set up {abbr}`TLS (Transport Layer Security)`. To do this, we recommend using [certbot](https://certbot.eff.org/).

1. Install certbot

   ```{code-block} sh
   sudo apt-get update
   sudo apt-get install certbot python3-certbot-nginx
   ```

2. Run certbot

   ```{code-block} sh
   sudo certbot --nginx -d $FUNKWHALE_HOSTNAME
   ```

That's it! certbot renews your certificate every 60 days, so you don't need to worry about renewing it.
