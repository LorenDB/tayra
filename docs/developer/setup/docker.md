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
   sudo docker compose -f dev.yml run --rm api funkwhale-manage fw users create --superuser
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

You can access your project at `http://localhost:8000`.
