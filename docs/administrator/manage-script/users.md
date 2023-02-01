# Manage users

The `funkwhale-manage` command line interface includes commands for user management. Use these commands to automate managing users from the command line.

All users-related commands are available under the `funkwhale-manage fw users` namespace.

## Create users

You can create users with the `funkwhale-manage` command line interface. There are different ways to create users depending on what approach you want to take.

### Create a user interactively

::::{tab-set}

:::{tab-item} Debian
:sync: debian

```{code-block} sh
venv/bin/funkwhale-manage fw users create
```

:::

:::{tab-item} Docker
:sync: docker

```{code-block} sh
sudo docker compose run --rm api funkwhale-manage fw users create
```

:::
::::

### Create a user with a random password

::::{tab-set}

:::{tab-item} Debian
:sync: debian

```{code-block} sh
venv/bin/funkwhale-manage fw users create --username <username> --email <user email> -p ""
```

:::

:::{tab-item} Docker
:sync: docker

```{code-block} sh
sudo docker compose run --rm api funkwhale-manage fw users create --username <username> --email <user email> -p ""
```

:::
::::

### Create a user with a password set from an environment variable

::::{tab-set}

:::{tab-item} Debian
:sync: debian

```{code-block} sh
export FUNKWHALE_CLI_USER_PASSWORD=<password>
venv/bin/funkwhale-manage fw users create --username <username> --email <user email>
```

:::

:::{tab-item} Docker
:sync: docker

```{code-block} sh
export FUNKWHALE_CLI_USER_PASSWORD=<password>
sudo docker compose run --rm api funkwhale-manage fw users create --username <username> --email <user email>
```

:::
::::

There are extra options for user configuration, such as quota and {term}`permissions`. Check the command help for more options.

::::{tab-set}

:::{tab-item} Debian
:sync: debian

```{code-block} sh
venv/bin/funkwhale-manage fw users --help
```

:::

:::{tab-item} Docker
:sync: docker

```{code-block} sh
sudo docker compose run --rm api funkwhale-manage fw users --help
```

:::
::::

## Update users

You can update user accounts using the `funkwhale-manage` command line interface. Update commands are available under the `funkwhale-manage fw users set` namespace.

### Set upload quota for a user

::::{tab-set}

:::{tab-item} Debian
:sync: debian

```{code-block} sh
venv/bin/funkwhale-manage fw users set --upload-quota 500 <user>
```

:::

:::{tab-item} Docker
:sync: docker

```{code-block} sh
sudo docker compose run --rm api funkwhale-manage fw users set --upload-quota 500 <user>
```

:::
::::

### Make users staff members

::::{tab-set}

:::{tab-item} Debian
:sync: debian

```{code-block} sh
venv/bin/funkwhale-manage fw users set --staff --superuser <user 1> <user 2>
```

:::

:::{tab-item} Docker
:sync: docker

```{code-block} sh
sudo docker compose run --rm api funkwhale-manage fw users set --staff --superuser <user 1> <user 2>
```

:::
::::

### Remove a user's staff privileges

::::{tab-set}

:::{tab-item} Debian
:sync: debian

```{code-block} sh
venv/bin/funkwhale-manage fw users set --no-staff --no-superuser <user>
```

:::

:::{tab-item} Docker
:sync: docker

```{code-block} sh
sudo docker compose run --rm api funkwhale-manage fw users set --no-staff --no-superuser <user>
```

:::
::::

### Give a user moderation permissions

::::{tab-set}

:::{tab-item} Debian
:sync: debian

```{code-block} sh
venv/bin/funkwhale-manage fw users set --permission-moderation <user>
```

:::

:::{tab-item} Docker
:sync: docker

```{code-block} sh
sudo docker compose run --rm api funkwhale-manage fw users set --permission-moderation <user>
```

:::
::::

### Reset a user's password

::::{tab-set}

:::{tab-item} Debian
:sync: debian

```{code-block} sh
venv/bin/funkwhale-manage fw users set --password "<password>" <user>
```

:::

:::{tab-item} Docker
:sync: docker

```{code-block} sh
sudo docker compose run --rm api funkwhale-manage fw users set --password "<password>" <user>
```

:::
::::

### Reset a user's password using an environment variable

::::{tab-set}

:::{tab-item} Debian
:sync: debian

```{code-block} sh
export FUNKWHALE_CLI_USER_UPDATE_PASSWORD=<password>
venv/bin/funkwhale-manage fw users set <user>
```

:::

:::{tab-item} Docker
:sync: docker

```{code-block} sh
export FUNKWHALE_CLI_USER_UPDATE_PASSWORD=<password>
sudo docker compose run --rm api funkwhale-manage fw users set <user>
```

:::
::::

There are extra options for updating users. Check the command help for more options.

::::{tab-set}

:::{tab-item} Debian
:sync: debian

```{code-block} sh
venv/bin/funkwhale-manage fw users set --help
```

:::

:::{tab-item} Docker
:sync: docker

```{code-block} sh
sudo docker compose run --rm api funkwhale-manage fw users set --help
```

:::
::::

## Delete users

### Delete a user's account but leave a reference to them in the database

This prevents the same username being used in future.

::::{tab-set}

:::{tab-item} Debian
:sync: debian

```{code-block} py
venv/bin/funkwhale-manage fw users rm <user>
```

:::

:::{tab-item} Docker
:sync: docker

```{code-block} py
sudo docker compose run --rm api funkwhale-manage fw users rm <user>
```

:::
::::

### Delete a user's account, including all references in the database

This means the username can be reused.

::::{tab-set}

:::{tab-item} Debian
:sync: debian

```{code-block} py
venv/bin/funkwhale-manage fw users rm --hard <user>
```

:::

:::{tab-item} Docker
:sync: docker

```{code-block} py
sudo docker compose run --rm api funkwhale-manage fw users rm --hard <user>
```

:::
::::

There are extra options for deleting users. Check the command help for more options.

::::{tab-set}

:::{tab-item} Debian
:sync: debian

```{code-block} sh
venv/bin/funkwhale-manage fw users rm --help
```

:::

:::{tab-item} Docker
:sync: docker

```{code-block} sh
sudo docker compose run --rm api funkwhale-manage fw users rm --help
```

:::
::::
