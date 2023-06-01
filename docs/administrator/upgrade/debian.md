# Upgrade your Debian Funkwhale installation

If you installed Funkwhale following the [Debian guide](../installation/debian.md), follow these steps to upgrade.

## Cleanup old funkwhale files

1. Stop the Funkwhale services.

   ```console
   # systemctl stop funkwhale.target
   ```

2. Navigate to your Funkwhale directory.

   ```console
   # cd /srv/funkwhale
   ```

3. Remove the old files.

   ```console
   # rm -Rf api/* front/* venv
   ```

## Download Funkwhale

1. Export the Funkwhale version you want to update to. You'll use this in the rest of the commands in this guide.

   ```{parsed-literal}
   export FUNKWHALE_VERSION={sub-ref}`version`
   ```

2. Follow the [Download Funkwhale](../installation/debian.md#3-download-funkwhale) instructions in the installation guide.
3. Follow the [Install the Funkwhale API](../installation/debian.md#4-install-the-funkwhale-api) instructions in the installation guide.

## Upgrade your systemd unit files

To make sure you receive any updates made to unit files, download the latest versions from the repo.

```console
# curl -L -o "/etc/systemd/system/funkwhale.target" "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/$FUNKWHALE_VERSION/deploy/funkwhale.target"
# curl -L -o "/etc/systemd/system/funkwhale-server.service" "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/$FUNKWHALE_VERSION/deploy/funkwhale-server.service"
# curl -L -o "/etc/systemd/system/funkwhale-worker.service" "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/$FUNKWHALE_VERSION/deploy/funkwhale-worker.service"
# curl -L -o "/etc/systemd/system/funkwhale-beat.service" "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/$FUNKWHALE_VERSION/deploy/funkwhale-beat.service"
```

## Update your reverse proxy configuration

To ensure your reverse proxy is up-to-date with changes, you should regenerate your Nginx configuration with each upgrade. To do this:

:::{include} /administrator/installation/debian.md
:start-after: Nginx update instructions
:end-before: Instructions end
:::

Once you've updated your configuration, reload Nginx.

```console
# systemctl reload nginx
```

## Update your Funkwhale instance

Once you have downloaded the new files, you can update your Funkwhale instance. To do this:

1. Install or upgrade all OS dependencies using the dependencies script.

   ```console
   # api/install_os_dependencies.sh install
   ```

2. Collect the new static files to serve.

   ```console
   # venv/bin/funkwhale-manage collectstatic --no-input
   ```

3. Apply new database migrations.

   ```console
   # sudo -u funkwhale venv/bin/funkwhale-manage migrate
   ```

4. Restart the Funkwhale services.

   ```console
   # systemctl start funkwhale.target
   ```

That's it! You've updated your Funkwhale pod. You should now see the new version running in your web browser.
