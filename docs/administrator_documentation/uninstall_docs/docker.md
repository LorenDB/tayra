# Uninstall Docker installation

To uninstall a Docker-based Funkwhale installation from your server, follow the instructions in this guide.

```{warning}
Removing Funkwhale data is __irreversible__. Make sure you [back up your data](../upgrade_docs/backup.md).
```

```{contents}
:local:
:depth: 1
```

## Stop the Docker containers

Before you remove any data, you need to stop the Funkwhale containers.

1. Navigate to your Funkwhale directory.

   ```{code} bash
   cd /srv/funkwhale
   ```

2. Stop the containers

   ```{code} bash
   docker-compose down
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

## Remove the containers and their volumes

```{warning}
This action is __irreversible__. Make sure you have [backed up your data](../upgrade_docs/backup.md) before proceeding.
```

Once you have stopped the containers, you can delete all containers and associated volumes.

```{code} bash
docker-compose rm -fsv
```

## Remove the Funkwhale directory

Once you have removed the containers and volumes, you can delete the Funkwhale directory.

```{code} bash
sudo rm -rf /srv/funkwhale
```

This deletes everything in the (`/srv/funkwhale/`) directory. If your content is hosted in an S3-compatible store, you need to delete this data separately.
