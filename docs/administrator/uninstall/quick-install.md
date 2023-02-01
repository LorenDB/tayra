# Uninstall using the quick install script

The Funkwhale quick install script doesn't currently offer an uninstall command. This is because you may be using its dependencies for other software. To uninstall a quick install Funkwhale installation, follow the instructions in this guide.

```{warning}
Removing Funkwhale data is __irreversible__. Make sure you [back up your data](../upgrade/backup.md).
```

```{contents}
:local:
:depth: 1
```

## Stop the Funkwhale server

Before you uninstall anything from your server, you need to stop the Funkwhale systemd services.

1. Stop all systemd services listed under the `funkwhale` target

   ```{code-block} sh
   sudo systemctl stop funkwhale.target
   ```

2. Disable all systemd services to prevent launch at startup.

   ```{code-block} sh
   sudo systemctl disable funkwhale-server
   sudo systemctl disable funkwhale-worker
   sudo systemctl disable funkwhale-beat
   ```

3. Remove the service files.

   ```{code-block} sh
   sudo rm /etc/systemd/system/funkwhale-server.service
   sudo rm /etc/systemd/system/funkwhale-worker.service
   sudo rm /etc/systemd/system/funkwhale-beat.service
   sudo rm /etc/systemd/system/funkwhale.target
   ```

4. Reload all services to pick up the changes.

   ```{code-block} sh
   sudo systemctl daemon-reload
   sudo systemctl reset-failed
   ```

## Remove the reverse proxy

To stop serving Funkwhale from your web server, you need to remove your reverse proxy configuration.

::::{tab-set}

:::{tab-item} Nginx
:sync: nginx

1. Remove the configuration files from your web host.

   ```{code-block} sh
   sudo rm /etc/nginx/sites-enabled/funkwhale.conf
   sudo rm /etc/nginx/sites-available/funkwhale.conf
   sudo rm /etc/nginx/funkwhale_proxy.conf
   ```

2. Reload the web server.

   ```{code-block} sh
   sudo systemctl reload nginx
   ```

:::

:::{tab-item} Apache2
:sync: apache2

1. Remove the configuration files from your web host.

   ```{code-block} sh
   sudo rm /etc/apache2/sites-enabled/funkwhale.conf
   sudo rm /etc/apache2/sites-available/funkwhale.conf
   ```

2. Reload the web server.

   ```{code-block} sh
   sudo service apache2 restart
   ```

:::
::::

## Remove the Funkwhale database

```{warning}
This action is __irreversible__. Make sure you have [backed up your data](../upgrade/backup.md) before proceeding.
```

Once you have stopped the Funkwhale services, you can remove the Funkwhale database.

1. Navigate to your Funkwhale directory.

   ```{code-block} sh
   cd /srv/funkwhale
   ```

2. Delete the Funkwhale database.

   ```{code-block} sh
   sudo -u postgres psql -c 'DROP DATABASE funkwhale;'
   ```

3. Delete the Funkwhale user.

   ```{code-block} sh
   sudo -u postgres psql -c 'DROP USER funkwhale;'
   ```

## Delete the Funkwhale account

```{warning}
This action deletes the `/srv/funkwhale/` directory. Make sure you have [backed up any data](../upgrade/backup.md) you want to keep.
```

Once you have removed the database, you can delete the `funkwhale` user and all associated data.

```{code-block} sh
sudo userdel -r funkwhale
```

This deletes the `funkwhale` user and everything in their home directory (`/srv/funkwhale/`). If your content is hosted in an S3-compatible store, you need to delete this data separately.

## Uninstall dependencies

The quick install script installs the following dependencies on your server:

::::{tab-set}

:::{tab-item} Apt
:sync: apt

```{code-block} text

build-essential
curl
ffmpeg
libjpeg-dev
libmagic-dev
libpq-dev
postgresql-client
python3-dev
libldap2-dev
libsasl2-dev
make

```

:::

:::{tab-item} Python
:sync: python

```{literalinclude} ../../../api/pyproject.toml
:language: toml
:lines: 9-59
```

:::
::::

Uninstall any dependencies you don't need.
