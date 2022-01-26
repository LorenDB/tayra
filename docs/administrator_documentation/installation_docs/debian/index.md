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

- Install `curl`.

   ```{code} bash
   sudo apt update # update apt cache
   sudo apt install curl
   ```

## 1. Install Funkwhale dependencies

To install Funkwhale on your server, you first need to install its dependencies. We provide all dependencies in a single file to enable you to install everything at once. You can pass the information from this file to `apt` using the following command:

```{code} bash
sudo apt install $(curl https://dev.funkwhale.audio/funkwhale/funkwhale/-/raw/$FUNKWHALE_VERSION/api/requirements.apt)
```

When prompted, hit {kbd}`y` to confirm the install.

That's it! `apt` installs all dependencies and tells you once it has finished.

## 2. Create a Funkwhale user

It's good practice to create a user on your server for Funkwhale administration. Doing this makes it easy to make sure you're running commands from the right place. Follow these steps to set up your user.

1. Create the `funkwhale` user and set its shell to `bash` and its home directory to `/srv/funkwhale`.

   ```{code} bash
   sudo useradd -r -s /usr/bin/bash -d /srv/funkwhale -m funkwhale
   ```

2. Create a password for the user. You need to do this so that you can use this user to perform database administration.

   ```{code} bash
   sudo passwd funkwhale
   ```

3. Finally, give the user `sudo` privileges. You need to do this so that the user can run administrative tasks.

   ```{code}
   usermod -aG sudo funkwhale
   ```

That's it! You've created your `funkwhale` user. Log in as this user when you want to perform any Funkwhale related tasks.

## 3. Download Funkwhale

Once you've created your `funkwhale` user you can download the Funkwhale software itself.

### Create the directory layout

1. Log in to your `funkwhale` account and go to the `/srv/funkwhale` directory.

   ```{code} bash
   cd /srv/funkwhale
   su funkwhale
   ```

2. Create the directories for Funkwhale.

   ```{code} bash
   mkdir -p config api data/static data/media data/music front
   ```

That's it! Your directory structure should look like this:

```{code}
.
├── config      # config / environment files
├── api         # the Funkwhale API
├── data        # files served by the API
   └── static   # storage location for persistent data
   └── media    # storage location for media files
   └── music    # storage location for audio files   
└── front       # frontend files for the user interface
```

### Download the Funkwhale release

Once you've created the directory structure you can download Funkwhale. Funkwhale comes in two parts: the API and the Frontend. You need both to run the application.

1. Download the API.

   ```{code} bash
   curl -L -o "api-$FUNKWHALE_VERSION.zip" "https://dev.funkwhale.audio/funkwhale/funkwhale/-/jobs/artifacts/$FUNKWHALE_VERSION/download?job=build_api"
   unzip "api-$FUNKWHALE_VERSION.zip" -d extracted 
   mv extracted/api/* api/ 
   rm -rf extracted rm api-$FUNKWHALE_VERSION.zip
   ```

2. Download the frontend

   ```{code} bash
   curl -L -o "front-$FUNKWHALE_VERSION.zip" "https://dev.funkwhale.audio/funkwhale/funkwhale/-/jobs/artifacts/$FUNKWHALE_VERSION/download?job=build_front" 
   unzip "front-$FUNKWHALE_VERSION.zip" -d extracted 
   mv extracted/front . 
   rm -rf extracted
   rm front-$FUNKWHALE_VERSION.zip
   ```

You're done! These commands put the software in the correct location for Funkwhale to serve them.

## 4. Install Python dependencies

The Funkwhale API is written in Python. You need to install the API's dependencies to run the software. We use [Poetry](https://python-poetry.org) to handle Python dependencies.

1. Install Poetry. Follow the steps in this wizard to set it up.

   ```{code} bash
   curl -sSL https://install.python-poetry.org | python3 -
   ```

2. Add Poetry to your `$PATH`. This allows you to use `poetry` commands.

   ```{code} bash
   export "$PATH=$HOME/.local/bin:$PATH" >> ~/.bashrc
   ```

3. Set up poetry in your `/srv/funkwhale/api` directory.

   ```{code} bash
   cd /srv/funkwhale/api
   poetry install
   ```

You're done! Poetry installs all Python dependencies.

## 5. Set up your environment file

The environment file contains options you can use to control your Funkwhale pod. Follow these steps to get a working environment up and running.

1. Download the `.env` template to your `/srv/funkwhale/config` directory.

   ```{code} bash
   curl -L -o /srv/funkwhale/config/.env "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/$FUNKWHALE_VERSION/deploy/env.prod.sample"
   ```

2. Generate a secret key for Django. This keeps your Funkwhale data secure. Do not share this key with anybody.

   ```{code} bash
   openssl rand -base64 45
   ```

3. Reduce the permissions on your `.env` file to `600`. This means that only the `funkwhale` user can read and write this file.

   ```{code} bash
   chmod 600 /srv/funkwhale/config/.env
   ```

4. Open the `.env` file in a text editor. For this example, we will use `nano`.

   ```{code} bash
   nano /srv/funkwhale/config/.env
   ```

5. Update the following settings:
   - Paste the secret key in the `DJANGO_SECRET_KEY` field.
   - Populate the `DATABASE_URL` field:

      ```{code}
      DATABASE_URL=postgresql://funkwhale@:5432/funkwhale
      ```

   - Populate the `CACHE_URL` field:

      ```{code}
      CACHE_URL=redis://127.0.0.1:6379/0
      ```

   - Populate the `FUNKWHALE_HOSTNAME` field with the URL of your server.

6. Hit {kbd}`ctrl + x` then {kbd}`y` to save the file and close `nano`.

You're done! Your environment file is now ready to go. You can check out a full list of configuration options in our Environment file guide.

## 6. Set up your database

Funkwhale uses a [PostgreSQL](https://www.postgresql.org/) database to store information. Follow these steps to set up your database.

1. Install PostgreSQL and the `postgresql-contrib` package. This package contains extra features that Funkwhale uses.

   ```{code} bash
   sudo apt-get install postgresql postgresql-contrib
   ```

2. Once you've installed PostgreSQL, launch a `psql` shell as the `postgres` user to set up your database.

   ```{code} bash
   sudo -u postgres psql
   ```

3. Create your Funkwhale database.

   ```{code} psql
   CREATE DATABASE funkwhale WITH ENCODING 'utf8';
   ```

4. Create a user for Funkwhale. This user needs all privileges so it can manage the database.

   ```{code} psql
   CREATE USER funkwhale;
   GRANT ALL PRIVILEGES ON DATABASE funkwhale TO funkwhale;
   ```

5. Once you're finished, exit the shell

   ```{code} psql
   exit
   ```

6. Run the following commands to create extra extensions for the `funkwhale` database.

   ```{code} bash
   sudo -u postgres psql funkwhale -c 'CREATE EXTENSION "unaccent";'
   sudo -u postgres psql funkwhale -c 'CREATE EXTENSION "citext";'
   ```

7. Your database is ready to be populated! Use the `manage.py` script to create the database structure.

   ```{code} bash
   cd /srv/funkwhale/api
   poetry run python manage.py migrate
   ```

````{note}
You may see the following warning when applying migrations:

```{code}
"Your models have changes that are not yet reflected in a migration, and so won't be applied."
```

You can safely ignore this warning.
````

That's it! You've finished setting up your database.

## 7. Set up Funkwhale

Once you have got your database up and running, you can get Funkwhale ready to launch. Use the built-in `manage.py` script to get things ready.

### Create a superuser for your pod

```{note}
You can create several superusers.
```

To start using Funkwhale, you need to create a superuser for your pod. This user has all the permissions needed to administrate the pod. Follow these steps to create a superuser.

```{code} bash
poetry run python manage.py createsuperuser
```

That's it! You can log in as this user when you finish setting up Funkwhale.

### Collect static files

Funkwhale uses several static assets to serve its frontend. Use `manage.py` to collect these files so that the webserver can serve them.

```{code} bash
poetry run python manage.py collectstatic
```

## 8. Set up systemd unit files

Funkwhale uses [systemd](https://www.freedesktop.org/wiki/Software/systemd/) to manage its services. systemd helps prevent downtime by bringing services back up if they fail. It also starts your Funkwhale services after a reboot. Follow these steps to set up Funkwhale services with systemd.

1. Download the sample unit files from Funkwhale.

   ```{code} bash
   sudo curl -L -o "/etc/systemd/system/funkwhale.target" "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/$FUNKWHALE_VERSION/deploy/funkwhale.target"
   sudo curl -L -o "/etc/systemd/system/funkwhale-server.service" "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/$FUNKWHALE_VERSION/deploy/funkwhale-server.service"
   sudo curl -L -o "/etc/systemd/system/funkwhale-worker.service" "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/$FUNKWHALE_VERSION/deploy/funkwhale-worker.service"
   sudo curl -L -o "/etc/systemd/system/funkwhale-beat.service" "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/$FUNKWHALE_VERSION/deploy/funkwhale-beat.service"
   ```

2. Reload systemd to register the new services.

   ```{code} bash
   sudo systemctl daemon-reload
   ```

3. Start all Funkwhale services.

   ```{code} bash
   sudo systemctl start funkwhale.target
   ```

4. Enable the services. Systemd can then start the services after a reboot.

   ```{code} bash
   sudo systemctl enable funkwhale-server
   sudo systemctl enable funkwhale-worker
   sudo systemctl enable funkwhale-beat
   ```

That's it! systemd keeps these services running and starts them up in the correct order after a reboot.

## 9. Set up a reverse proxy

Funkwhale uses a reverse proxy to serve content to users. We use [Nginx](https://nginx.com) to serve this proxy. Follow this guide to install an Nginx configuration using details from your `.env` file.

1. Install Nginx.

   ```{code} bash
   sudo apt-get update
   sudo apt-get install nginx
   ```

2. Download the Nginx templates from Funkwhale.

   ```{code} bash
   export FUNKWHALE_VERSION="1.2.1"
   sudo curl -L -o /etc/nginx/funkwhale_proxy.conf "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/$FUNKWHALE_VERSION/deploy/funkwhale_proxy.conf"
   sudo curl -L -o /etc/nginx/sites-available/funkwhale.template "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/$FUNKWHALE_VERSION/deploy/nginx.template"
   ```

3. Create an Nginx template with details from your `.env` file.

   ```{code} bash
   # Log in to a root shell.

   sudo su
   
   # Create an Nginx configuration using the Funkwhale template with details from your `.env` file.

   set -a && source /srv/funkwhale/config/.env && set +a
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

## 10. Set up TLS

To enable your users to connect to your pod securely, you need to set up {abbr}`TLS (Transport Layer Security)`. To do this, we recommend using the <acme.sh> script.

1. Download and run `acme.sh`. Replace `my@example.com` with your email address.

   ```{code} bash
   curl https://get.acme.sh | sh -s email=my@example.com
   ```

2. Generate a certificate. Replace `example.com` with your Funkwhale pod name.

   ```{code} bash
   acme.sh --issue -d example.com -w /home/funkwhale/public_html
   ```

3. Install the certificate to your Nginx config. Replace `example.com` with your Funkwhale pod name.

   ```{code} bash
   acme.sh --install-cert -d example.com \
   --key-file       /path/to/keyfile/in/nginx/key.pem  \
   --fullchain-file /path/to/fullchain/nginx/cert.pem \
   --reloadcmd     "service nginx force-reload"
   ```

That's it! acme.sh renews your certificate every 60 days, so you don't need to about renewing it.
