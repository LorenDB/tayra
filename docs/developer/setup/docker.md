# Develop using Docker

Funkwhale can be run in Docker containers for local development. You can work on any part of the Funkwhale codebase and run the container setup to test your changes. To work with Docker:

1. [Install Docker](https://docs.docker.com/install)
2. [Install docker compose](https://docs.docker.com/compose/install)
3. Clone the Funkwhale repository to your system. The `develop` branch is checked out by default

   ::::{tab-set}

   :::{tab-item} SSH

   ```sh
   git clone git@dev.funkwhale.audio/funkwhale/funkwhale.git
   cd funkwhale
   ```

   :::

   :::{tab-item} HTTPS

   ```sh
   git clone https://dev.funkwhale.audio/funkwhale/funkwhale.git
   cd funkwhale
   ```

   :::

   ::::

## Set up your Docker environment

````{note}

Funkwhale provides a `dev.yml` file that contains the required docker compose setup. You need to pass the `-f dev.yml` flag you run docker compose commands to ensure it uses this file. If you don't want to add this each time, you can export it as a `COMPOSE_FILE` variable:

```sh
export COMPOSE_FILE=dev.yml
```

````

To set up your Docker environment:

1. Create a `.env` file to enable customization of your setup.

   ```sh
   touch .env
   ```

2. Add the following variables to load images and enable access to Django admin pages:

   ```text
   MEDIA_URL=http://localhost:8000/media/
   STATIC_URL=http://localhost:8000/staticfiles/
   ```

3. Create a network for federation support

   ```sh
   sudo docker network create federation
   ```

Once you've set everything up, you need to build the containers. Run this command any time there are upstream changes or dependency changes to ensure you're up-to-date.

```sh
sudo docker compose -f dev.yml build
```

## Set up the database

Funkwhale relies on a postgresql database to store information. To set this up, you need to run the `funkwhale-manage migrate` command:

```sh
sudo docker compose -f dev.yml run --rm api funkwhale-manage migrate
```

This command creates all the required tables. You need to run this whenever there are changes to the API schema. You can run this at any time without causing issues.

## Set up local data

You need to create some local data to mimic a production environment.

1. Create a superuser so you can log in to your local app:

   ```sh
   sudo docker compose -f dev.yml run --rm api funkwhale-manage createsuperuser
   ```

2. Add some fake data to populate the database. The following command creates 25 artists with random albums, tracks, and metadata.

   ```sh
   artists=25 # Adds 25 fake artists
   command="from funkwhale_api.music import fake_data; fake_data.create_data($artists)"
   echo $command | sudo docker compose -f dev.yml run --rm -T api funkwhale-manage shell -i python
   ```

## Manage services

Once you have set up your containers, launch all services to start working on them:

   ```sh
   sudo docker compose -f dev.yml up front api nginx celeryworker
   ```

This gives you access to the following:

- The Funkwhale webapp on `http://localhost:8000`
- The Funkwhale API on `http://localhost:8000/api/v1`
- The Django admin interface on `http://localhost:8000/api/admin`

Once you're done with the containers, you can stop them all:

```sh
sudo docker compose -f dev.yml stop
```

If you want to destroy your containers, run the following:

```sh
sudo docker compose -f dev.yml down -v
```

## Set up federation support

Working on federation features requires some additional setup. You need to do the following:

1. Update your DNS resolver to resolve all your .dev hostnames locally
2. Set up a reverse proxy (such as traefik) to catch .dev requests with a TLS certificate
3. Set up two or more local instances

To resolve hostnames locally, run the following:

::::{tab-set}

:::{tab-item} dnsmasq

```sh
echo "address=/test/172.17.0.1" | sudo tee /etc/dnsmasq.d/test.conf
sudo systemctl restart dnsmasq
```

:::

:::{tab-item} NetworkManager

```sh
echo "address=/test/172.17.0.1" | sudo tee /etc/NetworkManager/dnsmasq.d/test.conf
sudo systemctl restart NetworkManager
```

:::

::::

To add a wildcard certificate, copy the test certificate from the `docker/ssl` folder. This certificate is a wildcard for `*.funkwhale.test`

```sh
sudo cp docker/ssl/test.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

To run a reverse proxy for your app:

1. Add the following configuration to your `.env` file:

   ```text
   # Remove any port binding so you can specify this per-instance
   VUE_PORT_BINDING=
   # Disable certificate validation
   EXTERNAL_REQUESTS_VERIFY_SSL=false
   # Ensure all links use https
   FUNKWHALE_PROTOCOL=https
   # Disable host ports binding for the nginx container so that traefik handles everything
   NGINX_PORTS_MAPPING=80
   ```

2. Launch traefik using the bundled configuration:

   ```sh
   sudo docker compose -f docker/traefik.yml up -d
   ```

3. Set up as many different projects as you need. Make sure the `COMPOSE_PROJECT_NAME` and `VUE_PORT` variables are unique per instance

   ```sh
   export COMPOSE_PROJECT_NAME=node2
   export VUE_PORT=1234  # this has to be unique for each instance
   sudo docker compose -f dev.yml run --rm api funkwhale-manage migrate
   sudo docker compose -f dev.yml run --rm api funkwhale-manage createsuperuser
   sudo docker compose -f dev.yml up nginx api front nginx api celeryworker
   ```

You can access your project at `https://{COMPOSE_PROJECT_NAME}.funkwhale.test`.
