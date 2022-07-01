# Manage users with manage.py

The {file}`manage.py` script includes commands for user management. Use these commands to automate managing users from the command line.

All users-related commands are available under the `python manage.py fw users` namespace.

## Create users

You can create users with the {file}`manage.py` script. There are different ways to create users depending on what approach you want to take.

### Create a user interactively

````{tabbed} Debian

```{code} bash
poetry run python manage.py fw users create
```

````

````{tabbed} Docker

```{code} bash
docker-compose run --rm api python manage.py fw users create
```

````

### Create a user with a random password

````{tabbed} Debian

```{code} bash
poetry run python manage.py fw users create --username <username> --email <user email> -p ""
```

````

````{tabbed} Docker

```{code} bash
docker-compose run --rm api python manage.py fw users create --username <username> --email <user email> -p ""
```

````

### Create a user with a password set from an environment variable

````{tabbed} Debian

```{code} bash
export FUNKWHALE_CLI_USER_PASSWORD=<password>
poetry run python manage.py fw users create --username <username> --email <user email>
```

````

````{tabbed} Docker

```{code} bash
export FUNKWHALE_CLI_USER_PASSWORD=<password>
docker-compose run --rm api python manage.py fw users create --username <username> --email <user email>
```

````

There are extra options for user configuration, such as quota and {term}`permissions`. Check the command help for more options.

````{tabbed} Debian

```{code} bash
poetry run python manage.py fw users --help
```

````

````{tabbed} Docker

```{code} bash
docker-compose run --rm api python manage.py fw users --help
```

````

## Update users

You can update user accounts using the {file}`manage.py` script. Update commands are available under the `python manage.py fw users set` namespace.

### Set upload quota for a user

````{tabbed} Debian

```{code} bash
poetry run python manage.py fw users set --upload-quota 500 <user>
```

````

````{tabbed} Docker

```{code} bash
docker-compose run --rm api python manage.py fw users set --upload-quota 500 <user>
```

````

### Make users staff members

````{tabbed} Debian

```{code} bash
poetry run python manage.py fw users set --staff --superuser <user 1> <user 2>
```

````

````{tabbed} Docker

```{code} bash
docker-compose run --rm api python manage.py fw users set --staff --superuser <user 1> <user 2>
```

````

### Remove a user's staff privileges

````{tabbed} Debian

```{code} bash
poetry run python manage.py fw users set --no-staff --no-superuser <user>
```

````

````{tabbed} Docker

```{code} bash
docker-compose run --rm api python manage.py fw users set --no-staff --no-superuser <user>
```

````

### Give a user moderation permissions

````{tabbed} Debian

```{code} bash
poetry run python manage.py fw users set --permission-moderation <user>
```

````

````{tabbed} Docker

```{code} bash
docker-compose run --rm api python manage.py fw users set --permission-moderation <user>
```

````

### Reset a user's password

````{tabbed} Debian

```{code} bash
poetry run python manage.py fw users set --password "<password>" <user>
```

````

````{tabbed} Docker

```{code} bash
docker-compose run --rm api python manage.py fw users set --password "<password>" <user>
```

````

### Reset a user's password using an environment variable

````{tabbed} Debian

```{code} bash
export FUNKWHALE_CLI_USER_UPDATE_PASSWORD=<password>
poetry run python manage.py fw users set <user>
```

````

````{tabbed} Docker

```{code} bash
export FUNKWHALE_CLI_USER_UPDATE_PASSWORD=<password>
docker-compose run --rm api python manage.py fw users set <user>
```

````

There are extra options for updating users. Check the command help for more options.

````{tabbed} Debian

```{code} bash
poetry run python manage.py fw users set --help
```

````

````{tabbed} Docker

```{code} bash
docker-compose run --rm api python manage.py fw users set --help
```

````

## Delete users

### Delete a user's account but leave a reference to them in the database

This prevents the same username being used in future.

````{tabbed} Debian

```{code} py
poetry run python manage.py fw users rm <user>
```

````

````{tabbed} Docker

```{code} py
docker-compose run --rm api python manage.py fw users rm <user>
```

````

### Delete a user's account, including all references in the database

This means the username can be reused.

````{tabbed} Debian

```{code} py
poetry run python manage.py fw users rm --hard <user>
```

````

````{tabbed} Docker

```{code} py
docker-compose run --rm api python manage.py fw users rm --hard <user>
```

````

There are extra options for deleting users. Check the command help for more options.

````{tabbed} Debian

```{code} bash
poetry run python manage.py fw users rm --help
```

````

````{tabbed} Docker

```{code} bash
docker-compose run --rm api python manage.py fw users rm --help
```

````
