# Install Funkwhale on Debian

We support [Debian](https://debian.org) and Debian-based Linux distributions. Follow these steps to set up Funkwhale on a Debian server.

```{contents}
:local:
:depth: 1
```

## Before you begin

- Set a `FUNKWHALE_VERSION` variable to the version you want to install. You will use this version for all commands in this guide.

  ```{parsed-literal}
  export FUNKWHALE_VERSION={sub-ref}`version`
  ```

- Install `curl`

  ```{code-block} sh
  sudo apt update # update apt cache
  sudo apt install curl
  ```

## 1. Install Funkwhale dependencies

To install Funkwhale on your server, you first need to install its dependencies. We provide all dependencies in a single file to enable you to install everything at once. You can pass the information from this file to `apt` using the following command:

```{code-block} sh
sudo apt install $(curl https://dev.funkwhale.audio/funkwhale/funkwhale/-/raw/$FUNKWHALE_VERSION/deploy/requirements.apt)
```

When prompted, hit {kbd}`y` to confirm the install.

That's it! `apt` installs all dependencies and tells you once it has finished.

## 2. Create a Funkwhale user

It's good practice to create a user on your server for Funkwhale administration. Doing this makes it easy to make sure you're running commands from the right place. Follow these steps to set up your user.

Create the `funkwhale` user and set its shell to `bash` and its home directory to `/srv/funkwhale`.

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

## 3. Download Funkwhale

Once you've created your `funkwhale` user you can download the Funkwhale software itself.

### Create the directory layout

1. Go to the `/srv/funkwhale` directory.

   ```{code-block} sh
   cd /srv/funkwhale
   ```

2. Create the directories for Funkwhale.

   ```{code-block} sh
   sudo mkdir -p config api data/static data/media data/music front
   ```

3. Allow the Funkwhale user to write to the data directories.

   ```{code-block} sh
   sudo chown -R funkwhale:funkwhale data
   ```

That's it! Your directory structure should look like this:

```{code-block} text
.
├── api           # the Funkwhale API
├── config        # config / environment files
├── data          # files served by the API
|   ├── media     # storage location for media files
|   ├── music     # storage location for audio files
|   └── static    # storage location for persistent data
└── front         # frontend files for the user interface
```

### Download the Funkwhale release

Once you've created the directory structure you can download Funkwhale. Funkwhale comes in two parts: the API and the Frontend. You need both to run the application.

1. Download the API.

   ```{code-block} sh
   sudo curl -L -o "api-$FUNKWHALE_VERSION.zip" "https://dev.funkwhale.audio/funkwhale/funkwhale/-/jobs/artifacts/$FUNKWHALE_VERSION/download?job=build_api"
   sudo unzip "api-$FUNKWHALE_VERSION.zip" -d extracted
   sudo mv extracted/api/* api/
   sudo rm -rf extracted api-$FUNKWHALE_VERSION.zip
   ```

2. Download the frontend

   ```{code-block} sh
   sudo curl -L -o "front-$FUNKWHALE_VERSION.zip" "https://dev.funkwhale.audio/funkwhale/funkwhale/-/jobs/artifacts/$FUNKWHALE_VERSION/download?job=build_front"
   sudo unzip "front-$FUNKWHALE_VERSION.zip" -d extracted
   sudo mv extracted/front .
   sudo rm -rf extracted front-$FUNKWHALE_VERSION.zip
   ```

You're done! These commands put the software in the correct location for Funkwhale to serve them.

## 4. Install the Funkwhale API

The Funkwhale API is written in Python. You need to install the API's package to run the software:

1. Set up a Python virtual environment:

   ```{code-block} sh
   cd /srv/funkwhale
   sudo python3 -m venv venv
   sudo venv/bin/pip install --upgrade pip wheel
   ```

2. Install the Funkwhale API package and dependencies:

   ```{code-block} sh
   sudo venv/bin/pip install --editable ./api
   ```

You're done!

## 5. Set up your environment file

The environment file contains options you can use to control your Funkwhale pod. Follow these steps to get a working environment up and running.

1. Download the `.env` template to your `/srv/funkwhale/config` directory.

   ```{code-block} sh
   sudo curl -L -o /srv/funkwhale/config/.env "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/$FUNKWHALE_VERSION/deploy/env.prod.sample"
   ```

2. Generate a secret key for Django. This keeps your Funkwhale data secure. Do not share this key with anybody.

   ```{code-block} sh
   openssl rand -base64 45
   ```

3. Reduce the permissions on your `.env` file to `600`. This means that only the `funkwhale` user can read and write this file.

   ```{code-block} sh
   sudo chown funkwhale:funkwhale /srv/funkwhale/config/.env
   sudo chmod 600 /srv/funkwhale/config/.env
   ```

4. Open the `.env` file in a text editor. For this example, we will use `nano`.

   ```{code-block} sh
   sudo nano /srv/funkwhale/config/.env
   ```

5. Update the following settings:

   - Paste the secret key in the `DJANGO_SECRET_KEY` field.
   - Populate the `DATABASE_URL` field:

     ```{code-block} text
     DATABASE_URL=postgresql://funkwhale@:5432/funkwhale
     ```

   - Populate the `CACHE_URL` field:

     ```{code-block} text
     CACHE_URL=redis://127.0.0.1:6379/0
     ```

   - Populate the `FUNKWHALE_HOSTNAME` field with the domain name of your server.

6. Hit {kbd}`ctrl + x` then {kbd}`y` to save the file and close `nano`.

You're done! Your environment file is now ready to go. You can check out a full list of configuration options in our Environment file guide.

## 6. Set up your database

Funkwhale uses a [PostgreSQL](https://www.postgresql.org/) database to store information. Follow these steps to set up your database.

1. Install PostgreSQL and the `postgresql-contrib` package. This package contains extra features that Funkwhale uses.

   ```{code-block} sh
   sudo apt-get install postgresql postgresql-contrib
   ```

2. Once you've installed PostgreSQL, launch a `psql` shell as the `postgres` user to set up your database.

   ```{code-block} sh
   sudo -u postgres psql
   ```

3. Create your Funkwhale database.

   ```{code-block} psql
   CREATE DATABASE funkwhale WITH ENCODING 'utf8';
   ```

4. Create a user for Funkwhale. This user needs all privileges so it can manage the database.

   ```{code-block} psql
   CREATE USER funkwhale;
   GRANT ALL PRIVILEGES ON DATABASE funkwhale TO funkwhale;
   ```

5. Once you're finished, exit the shell

   ```{code-block} psql
   exit
   ```

6. Run the following commands to create extra extensions for the `funkwhale` database.

   ```{code-block} sh
   sudo -u postgres psql funkwhale -c 'CREATE EXTENSION "unaccent";'
   sudo -u postgres psql funkwhale -c 'CREATE EXTENSION "citext";'
   ```

7. Your database is ready to be populated! Use the `funkwhale-manage` command line interface to create the database structure.

   ```{code-block} sh
   cd /srv/funkwhale
   sudo -u funkwhale venv/bin/funkwhale-manage migrate
   ```

````{note}
You may see the following warning when applying migrations:

```{code-block} text
"Your models have changes that are not yet reflected in a migration, and so won't be applied."
```

You can safely ignore this warning.
````

That's it! You've finished setting up your database.

## 7. Set up Funkwhale

Once you've got your database up and running, you can get Funkwhale ready to launch. Use the built-in `funkwhale-manage` command line interface to get things ready.

### Create a superuser for your pod

```{note}
You can create several superusers.
```

To start using Funkwhale, you need to create a superuser for your pod. This user has all the permissions needed to administrate the pod. Follow these steps to create a superuser.

```{code-block} sh
sudo -u funkwhale venv/bin/funkwhale-manage createsuperuser
```

That's it! You can log in as this user when you finish setting up Funkwhale.

### Collect static files

Funkwhale uses several static assets to serve its frontend. Use the `funkwhale-manage` command line interface to collect these files so that the webserver can serve them.

```{code-block} sh
sudo venv/bin/funkwhale-manage collectstatic
```

## 8. Set up systemd unit files

Funkwhale uses [systemd](https://www.freedesktop.org/wiki/Software/systemd/) to manage its services. systemd helps prevent downtime by bringing services back up if they fail. It also starts your Funkwhale services after a reboot. Follow these steps to set up Funkwhale services with systemd.

1. Download the sample unit files from Funkwhale.

   ```{code-block} sh
   sudo curl -L -o "/etc/systemd/system/funkwhale.target" "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/$FUNKWHALE_VERSION/deploy/funkwhale.target"
   sudo curl -L -o "/etc/systemd/system/funkwhale-server.service" "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/$FUNKWHALE_VERSION/deploy/funkwhale-server.service"
   sudo curl -L -o "/etc/systemd/system/funkwhale-worker.service" "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/$FUNKWHALE_VERSION/deploy/funkwhale-worker.service"
   sudo curl -L -o "/etc/systemd/system/funkwhale-beat.service" "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/$FUNKWHALE_VERSION/deploy/funkwhale-beat.service"
   ```

2. Reload systemd to register the new services.

   ```{code-block} sh
   sudo systemctl daemon-reload
   ```

3. Start all Funkwhale services.

   ```{code-block} sh
   sudo systemctl start funkwhale.target
   ```

4. Enable the services. Systemd can then start the services after a reboot.

   ```{code-block} sh
   sudo systemctl enable --now funkwhale.target
   ```

That's it! systemd keeps these services running and starts them up in the correct order after a reboot.

## 9. Set up a reverse proxy

Funkwhale uses a reverse proxy to serve content to users. We use [Nginx](https://nginx.com) to serve this proxy. Follow this guide to install an Nginx configuration using details from your `.env` file.

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
   # curl -L -o /etc/nginx/sites-available/funkwhale.template "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/$FUNKWHALE_VERSION/deploy/nginx.template"
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

## 10. Set up TLS

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
