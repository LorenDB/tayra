# 7. Set up Funkwhale

Once you have got your database up and running, you can get Funkwhale ready to launch. Use the built-in `manage.py` script to get things ready.

```{contents}
:local:
```

## Create a superuser for your pod

```{note}
You can create several superusers.
```

To start using Funkwhale, you need to create a superuser for your pod. This user has all the permissions needed to administrate the pod. Follow these steps to create a superuser.

```{code} bash
poetry run python manage.py createsuperuser
```

That's it! You can log in as this user when you finish setting up Funkwhale.

## Collect static files

Funkwhale uses several static assets to serve its frontend. Use `manage.py` to collect these files so that the webserver can serve them.

```{code} bash
poetry run python manage.py collectstatic
```
