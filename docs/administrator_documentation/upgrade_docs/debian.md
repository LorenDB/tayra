# Upgrade your Debian Funkwhale installation

If you installed Funkwhale following the [Debian guide](../installation_docs/debian), follow these steps to upgrade.

## Download the updated files

1. SSH into your server.
2. Log in as your `funkwhale` user.

   ```{code} bash
   su funkwhale
   ```

3. Navigate to your Funkwhale directory.

   ```{code} bash
   cd /srv/funkwhale
   ```

4. Stop the Funkwhale services.

   ```{code} bash
   sudo systemctl stop funkwhale.target
   ```

5. Export the Funkwhale version you want to update to. You'll use this in the rest of the commands in this guide.

   ```{parsed-literal}
   export FUNKWHALE_VERSION={sub-ref}`version`
   ```

6. Download the API files for your chosen Funkwhale version.

   ```{code} bash
   curl -L -o "api-$FUNKWHALE_VERSION.zip" "https://dev.funkwhale.audio/funkwhale/funkwhale/-/jobs/artifacts/$FUNKWHALE_VERSION/download?job=build_api"
   ```

7. Extract the downloaded archive to a new directory.

   ```{code} bash
   unzip "api-$FUNKWHALE_VERSION.zip" -o api_new
   ```

8. Remove the old `api` directory and move the extracted directory to the `api` directory.

   ```{code} bash
   rm -rf api/ && mv api_new api
   ```

9. Remove the downloaded archive file.

   ```{code} bash
   rm api-$FUNKWHALE_VERSION.zip
   ```

## Update your Funkwhale instance

Once you have downloaded the new files, you can update your Funkwhale instance. To do this:

1. Install or upgrade all OS dependencies using the dependencies script.

   ```{code} bash
   sudo api/install_os_dependencies.sh install
   ```

2. Enter the `api` directory to run the following commands.

   ```{code} bash
   cd api
   ```

3. Install all Python dependencies using `poetry`.

   ```{code} bash
   poetry install
   ```

4. Collect the new static files to serve.

   ```{code} bash
   poetry run python manage.py collectstatic --no-input
   ```

5. Apply new database migrations.

   ```{code} bash
   poetry run python manage.py migrate
   ```

6. Restart the Funkwhale services.

   ```{code} bash
   sudo systemctl start funkwhale.target
   ```

That's it! You've updated your Funkwhale pod. You should now see the new version running in your web browser.
