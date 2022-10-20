# Install a plugin

Once you have [created your plugin](create.md), you can install it on your Funkwhale pod.

## Install a local plugin

To install a plugin located on your server:

1. Add the plugin directory to the `FUNKWHALE_PLUGINS_PATH` variable in your `.env` file
2. Add the plugin name to the `FUNKWHALE_PLUGINS` variable in your `.env` file

   ```{code-block} text
   FUNKWHALE_PLUGINS=myplugin,anotherplugin
   ```

3. Restart Funkwhale to pick up the changes

## Install a third-party plugin

You can install third-party plugins using the `manage.py` script. To do this:

1. Add the plugin name to the `FUNKWHALE_PLUGINS` variable in your `.env` file

   ```{code-block} text
   FUNKWHALE_PLUGINS=myplugin,anotherplugin
   ```

2. Call the `manage.py` script with the location of the plugin archive

   :::: {tab-set}

   :::{tab-item} Debian

   ```{code-block} shell
   python manage.py fw plugins install https://plugin_url.zip
   ```

   :::

   :::{tab-item} Docker

   ```{code-block} shell
   docker-compose run --rm api python manage.py fw plugins install https://plugin_url.zip
   ```

   :::

   ::::

3. Restart Funkwhale to pick up the changes
