# Write a plugin

You can write plugins to extend the features of your Funkwhale pod. Follow the instructions in this guide to get started with your first plugin.

```{contents}
:local:
:depth: 2
```

## Before you begin

Before you start writing your plugin, you need to understand the following core concepts:

```{contents}
:local:
:depth: 1
```

We'll explain each of these concepts in the next few sections

### Scopes

Plugins fall into two different **scopes**:

1. User-level plugins that are configured by end-users for their own use
2. Pod-level plugins that are configured by pod admins and are not connected to a particular user

User-level plugins can also be used to import files from a third-party service, such as cloud storage or FTP.

### Hooks

**Hooks** are entrypoints that allow your plugin to listen to changes. You can create hooks to react to different  events that occur in the Funkwhale application.

An example of this can be seen in our Scrobbler plugin. We register a `LISTENING_CREATED` hook to notify any registered callback function when a listening is recorded. When a user listens to a track, the `notfy_lastfm` function fires.

```{code-block} python
from config import plugins
from .funkwhale_startup import PLUGIN

@plugins.register_hook(plugins.LISTENING_CREATED, PLUGIN)
def notify_lastfm(listening, conf, **kwargs):
    # do something
```

#### Available hooks

```{eval-rst}
.. autodata:: config.plugins.LISTENING_CREATED
```

### Filters

**Filters** are entrypoints that allow you to modify or add information. When you use the `register_filter` decorator, your function should return a value to be used by the server.

In this example, the `PLUGINS_DEPENDENCIES` filter is used to install additional dependencies required by your plugin. The `dependencies` function returns the additional dependency `django_prometheus` to request the dependency be installed by the server.

```{code-block} python
# funkwhale_startup.py
# ...
from config import plugins

@plugins.register_filter(plugins.PLUGINS_DEPENDENCIES, PLUGIN)
def dependencies(dependencies, **kwargs):
    return dependencies + ["django_prometheus"]

```

#### Available filters

```{eval-rst}
.. autodata:: config.plugins.PLUGINS_DEPENDENCIES
.. autodata:: config.plugins.PLUGINS_APPS
.. autodata:: config.plugins.MIDDLEWARES_BEFORE
.. autodata:: config.plugins.MIDDLEWARES_AFTER
.. autodata:: config.plugins.URLS
```

## Write your plugin

Once you know what type of plugin you want to write and what entrypoint you want to use, you can start writing your plugin.

Plugins are made up of the following 3 files:

- `__init__.py` - indicates that the directory is a Python package
- `funkwhale_startup.py` - the file that loads during Funkwhale initialization
- `funkwhale_ready.py` - the file that loads when Funkwhale is configured and ready

### Declare your plugin

You need to declare your plugin and its configuration options so that Funkwhale knows how to load the plugin. To do this, you must declare a new `plugins` instance in your `funkwhale_startup.py` file.

Your `plugins` should include the following information:

```{list-table}
:header-rows: 1

   * - Parameter
      - Data type
      - Description
   * - `name`
      - String
      - The name of your plugin, used in the `.env` file
   * - `label` 
      - String
      - The readable label that appears in the Funkwhale frontend
   * - `description` 
      - String
      - A meaningful description of your plugin and what it does
   * - `version` 
      - String
      - The version number of your plugin
   * - `user` 
      - Boolean
      - Whether the plugin is a **user-level** plugin or a **pod-level** plugin. See [scopes](#scopes) for more information
   * - `conf`
      - Array of Objects
      - A list of configuration options

```

In this example, we declare a new **user-level** plugin called "My Plugin". The user can configure a `greeting` in the plugin configuration.

```{code-block} python
# funkwhale_startup.py
from config import plugins

PLUGIN = plugins.get_plugin_config(
    name="myplugin",
    label="My Plugin",
    description="An example plugin that greets you",
    version="0.1",
    user=True,
    conf=[
        # This configuration option is editable by each user
        {"name": "greeting", "type": "text", "label": "Greeting", "default": "Hello"},
    ],
)
```

### Write your plugin logic

Once you've declared your plugin, you can write the plugin code in your `funkwhale_ready.py` file.

```{note}
You must import your plugin declaration from your `funkwhale_startup.py` file.
```

In this example, we create a simple API endpoint that returns a greeting to the user. To do this:

1. We create a new APIView class that accepts a `GET` request
2. We read the greeting value from the plugin `conf`
3. We return the greeting value with the user's username
4. We register this view at the endpoint `/greeting`

```{code-block} python
# funkwhale_ready.py
from django.urls import path
from rest_framework import response
from rest_framework import views

from config import plugins

# Import the plugin declaration from funkwhale_startup
from .funkwhale_startup import PLUGIN

# Create a new APIView class
class GreetingView(views.APIView):
    permission_classes = []
    # Register a GET response
    def get(self, request, *args, **kwargs):
        # Check the conf value of the plugin for the user
        conf = plugins.get_conf(PLUGIN["name"], request.user)
        if not conf["enabled"]:
            # Return an error code if the user hasn't enabled the plugin
            return response.Response(status=405)
        # Set the greeting value to the user's configured greeting
        greeting = conf["conf"]["greeting"]
        data = {
            # Append the user's username to the greeting
            "greeting": "{} {}!".format(greeting, request.user.username)
        }
        # Return the greeting
        return response.Response(data)

# Register the new APIView at the /greeting endpoint
@plugins.register_filter(plugins.URLS, PLUGIN)
def register_view(urls, **kwargs):
    return urls + [
        path('greeting', GreetingView.as_view())
    ]
```

### Result

Here is an example of how the above plugin works:

1. User "Harry" enables the plugin
2. "Harry" changes the greeting to "You're a wizard"
3. "Harry" visits the `/greeting` endpoint in their browser
4. The browser returns the message "You're a wizard Harry" 
