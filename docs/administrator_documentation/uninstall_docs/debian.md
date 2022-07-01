# Uninstall Debian installation

To uninstall Funkwhale from your Debian server, follow the instructions in this guide.

```{warning}
Removing Funkwhale data is __irreversible__. Make sure you [back up your data](../upgrade_docs/backup.md).
```

```{contents}
:local:
:depth: 1
```

## Stop the Funkwhale server

Before you uninstall anything from your server, you need to stop the Funkwhale systemd services.

1. Stop all systemd services listed under the `funkwhale` target

   ```{code} bash
   sudo systemctl stop funkwhale.target
   ```

2. Disable all systemd services to prevent launch at startup.

   ```{code} bash
   sudo systemctl disable funkwhale-server
   sudo systemctl disable funkwhale-worker
   sudo systemctl disable funkwhale-beat
   ```

3. Remove the service files.

   ```{code} bash
   sudo rm /etc/systemd/system/funkwhale-server.service
   sudo rm /etc/systemd/system/funkwhale-worker.service
   sudo rm /etc/systemd/system/funkwhale-beat.service
   sudo rm /etc/systemd/system/funkwhale.target
   ```

4. Reload all services to pick up the changes.

   ```{code} bash
   sudo systemctl daemon-reload
   sudo systemctl reset-failed
   ```

## Remove the reverse proxy

To stop serving Funkwhale from your web server, you need to remove your reverse proxy configuration.

````{tabbed} Nginx

1. Remove the configuration files from your web host.

   ```{code} bash
   sudo rm /etc/nginx/sites-enabled/funkwhale.conf
   sudo rm /etc/nginx/sites-available/funkwhale.conf
   sudo rm /etc/nginx/funkwhale_proxy.conf
   ```

2. Reload the web server.

   ```{code} bash
   sudo systemctl reload nginx
   ```

````

````{tabbed} Apache2

1. Remove the configuration files from your web host.

   ```{code} bash
   sudo rm /etc/apache2/sites-enabled/funkwhale.conf
   sudo rm /etc/apache2/sites-available/funkwhale.conf
   ```

2. Reload the web server.

   ```{code} bash
   sudo service apache2 restart
   ```

````

## Remove the Funkwhale database

```{warning}
This action is __irreversible__. Make sure you have [backed up your data](../upgrade_docs/backup.md) before proceeding.
```

Once you have stopped the Funkwhale services, you can remove the Funkwhale database.

1. Navigate to your Funkwhale directory.

   ```{code} bash
   cd /srv/funkwhale
   ```

2. Delete the Funkwhale database.

   ```{code} bash
   sudo -u postgres psql -c 'DROP DATABASE funkwhale;'
   ```

3. Delete the Funkwhale user.

   ```{code} bash
   sudo -u postgres psql -c 'DROP USER funkwhale;'
   ```

## Delete  the Funkwhale account

```{warning}
This action deletes the `/srv/funkwhale/` directory. Make sure you have [backed up any data](../upgrade_docs/backup.md) you want to keep.
```

Once you have removed the database, you can delete the `funkwhale` user and all associated data.

```{code} bash
sudo userdel -r funkwhale
```

This deletes the `funkwhale` user and everything in their home directory (`/srv/funkwhale/`). If your content is hosted in an S3-compatible store, you need to delete this data separately.

## Uninstall dependencies

Funkwhale uses the following dependencies on your server:

````{tabbed} apt

```{code} txt

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

````

````{tabbed} Python

```{literalinclude} ../../../api/pyproject.toml
:language: toml
:lines: 9-59
```

````

Uninstall any dependencies you don't need.
