# Customize the Funkwhale frontend

You can customize the look and behavior of the Funkwhale UI using a JSON configuration file. This file enables you to make very basic changes to the Funkwhale web app.

## Set up your custom configuration

### Create your configuration file

To customize your Funkwhale pod, you need to serve a {file}`settings.json` file at `https://yourinstanceurl/settings.json`. Follow these steps to set up your configuration file:

1. SSH into your Funkwhale server.
2. Navigate to your `/srv/funkwhale` folder

   ```{code} bash
   cd /srv/funkwhale
   ```

3. Create a new `custom` directory for your file.

   ```{code} bash
   mkdir custom
   ```

4. Create a new config file and populate it with placeholder settings.

   ```{code} bash
   cat <<EOF > custom/settings.json
   {
   "additionalStylesheets": [],
   "defaultServerUrl": null
   }
   EOF
   ```

```{dropdown} Supported parameters

| Parameter               | Data type  | Description                                                                                   | Example                        |
|-------------------------|------------|-----------------------------------------------------------------------------------------------|--------------------------------|
| `additionalStylesheets` | Array<URL> | A list of URLs (relative or absolute) pointing to stylesheets.                                | `["https://test/theme.css"]`   |
| `defaultServerUrl`      | URL        | The URL of the API server you want to connect the frontend to. Defaults to the current domain | `"https://api.yourdomain.com"` |

```

### Configure your reverse proxy

Once you've created your {file}`settings.json` file you need to configure your reverse proxy to serve it.

````{tabbed} Nginx

Add the following snippet to your {file}`/etc/nginx/sites-available/funkwhale.conf` config file:

```
location /settings.json {
   alias /srv/funkwhale/custom;
}
```

````

````{tabbed} Apache

Add the following snippet to your vhost configuration:

```
Alias /settings.json /srv/funkwhale/custom/settings.json
```

````

Reload your webserver. You should be able to see the contents of your configuration file at `https://yourinstanceurl/settings.json`.

## Add a custom theme

You can use a custom stylesheet to theme your Funkwhale pod. To do this:

1. Navigate to your {file}`/srv/funkwhale/custom` directory.

   ```{code} bash
   cd /srv/funkwhale/custom
   ```

2. Copy your CSS file to this directory, or create a new one.

   ```{code} bash
   # A basic CSS file. Turns the pod's background red.

   cat <<EOF > custom.css
   body {
   background-color: red;
   }
   EOF
   ```

3. Add the location of your CSS file to the `additionalStylesheets` parameter in your {file}`settings.json` file.

   ```{code} bash
   nano settings.json

   # Add ["/front/custom/custom.css"] to the additionalStylesheets parameter
   # The resulting file looks like this:
   # {
   #   "additionalStylesheets": ["/front/custom/custom.css"],
   #   "defaultServerUrl": null
   # }
   ```

4. Add the whole {file}`custom` dir to your vhost configuration.

   ````{tabbed} Nginx

   Add the following to your {file}`/etc/nginx/sites-available/funkwhale.conf` file:

   ```
   location /custom {
      alias /srv/funkwhale/custom;
   }
   ```
   ````

   ````{tabbed} Apache

   Add the following to your vhost file.

   ```
   Alias /custom /srv/funkwhale/custom

   <Directory "/srv/funkwhale/custom">
   Options FollowSymLinks
   AllowOverride None
   Require all granted
   </Directory>
   ```
   ````

5. Restart your webserver.

Refresh your Funkwhale app. The background should now be red.
