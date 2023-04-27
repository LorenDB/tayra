# Upgrade your Debian Funkwhale installation

If you installed Funkwhale following the [Debian guide](../installation/debian.md), follow these steps to upgrade.

## Cleanup old funkwhale files

1. Stop the Funkwhale services.

   ```{code-block} sh
   sudo systemctl stop funkwhale.target
   ```

2. Navigate to your Funkwhale directory.

   ```{code-block} sh
   cd /srv/funkwhale
   ```

3. Remove the old files.

   ```{code-block} sh
   sudo rm -Rf api/* front/* venv
   ```

## Download Funkwhale

1. Export the Funkwhale version you want to update to. You'll use this in the rest of the commands in this guide.

   ```{parsed-literal}
   export FUNKWHALE_VERSION={sub-ref}`version`
   ```

2. Follow the [Download Funkwhale](../installation/debian.md#3-download-funkwhale) instructions in the installation guide.
3. Follow the [Install the Funkwhale API](../installation/debian.md#4-install-the-funkwhale-api) instructions in the installation guide.


## Update your reverse proxy configuration

To ensure your reverse proxy is up-to-date with changes, you should regenerate your Nginx configuration with each upgrade. To do this:

1. Log in to a root shell to make changes to the config files

   ```console
   $ sudo su
   ```

2. Download the new Nginx templates from Funkwhale

   ```console
   # curl -L -o /etc/nginx/funkwhale_proxy.conf "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/$FUNKWHALE_VERSION/deploy/funkwhale_proxy.conf"
   # curl -L -o /etc/nginx/sites-available/funkwhale.template "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/$FUNKWHALE_VERSION/deploy/nginx.template"
   ```

3. Update the Nginx configuration with details from your {file}`.env` file

   ```console
   # set -a && source /srv/funkwhale/config/.env && set +a
   envsubst "`env | awk -F = '{printf \" $%s\", $$1}'`" \
      < /etc/nginx/sites-available/funkwhale.template \
      > /etc/nginx/sites-available/funkwhale.conf
   ```

4. Check the configuration file to make sure the template values have been updated properly

   ```console
   # grep '${' /etc/nginx/sites-enabled/funkwhale.conf
   ```

5. Restart Nginx

   ```console
   # systemctl restart nginx
   ```


## Update your Funkwhale instance

Once you have downloaded the new files, you can update your Funkwhale instance. To do this:

1. Install or upgrade all OS dependencies using the dependencies script.

   ```{code-block} sh
   sudo api/install_os_dependencies.sh install
   ```

2. Collect the new static files to serve.

   ```{code-block} sh
   sudo venv/bin/funkwhale-manage collectstatic --no-input
   ```

3. Apply new database migrations.

   ```{code-block} sh
   sudo -u funkwhale venv/bin/funkwhale-manage migrate
   ```

4. Restart the Funkwhale services.

   ```{code-block} sh
   sudo systemctl start funkwhale.target
   ```

That's it! You've updated your Funkwhale pod. You should now see the new version running in your web browser.
