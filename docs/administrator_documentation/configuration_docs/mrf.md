# Message Rewrite Facility (MRF)

Funkwhale includes a feature that mimics [Pleroma’s Message Rewrite Facility (MRF)](https://docs-develop.pleroma.social/backend/configuration/mrf/). The MRF enables instance admins to create custom moderation rules. You can use these rules to complement Funkwhale's [built-in moderation tools](../../moderator_documentation/index.md).

## Architecture

The MRF is a pluggable system that processes messages and forwards them to a list of registered policies. Each policy can mutate the message, leave it as is, or discard it.

We implement some of Funkwhale's built-in moderation tools as a MRF policy. For example:

- Allow-list, when checking incoming messages ([code](https://dev.funkwhale.audio/funkwhale/funkwhale/blob/stable/api/funkwhale_api/moderation/mrf_policies.py)).
- Domain and user blocking, when checking incoming messages ([code](https://dev.funkwhale.audio/funkwhale/funkwhale/blob/stable/api/funkwhale_api/federation/mrf_policies.py))

```{note}
Pleroma MRF policies can also affect outgoing messages. This is not currently supported in Funkwhale.
```

## Disclaimer

Writing custom MRF rules can impact the performance and stability of your pod. It can also affect message delivery. Every time your pod receives a message it calls your policy.

The Funkwhale project consider all custom MRF policies to fall under the purview of the AGPL. This means you're required to release the source of your custom MRF policy modules publicly.

## Write your first MRF policy

MRF policies are written as Python 3 functions that take at least one `payload` parameter. This payload is the raw ActivityPub message, received via HTTP, following the HTTP signature check.

In the example below we write a policy that discards all Follow requests from listed domains:

```{code-block} py
import urllib.parse
from funkwhale_api.moderation import mrf

BLOCKED_FOLLOW_DOMAINS = ['domain1.com', 'botdomain.org']

# You need to register the policy to apply it.

# The name can be anything you want. It will appear in the mrf logs
@mrf.inbox.register(name='blocked_follow_domains')
def blocked_follow_domains_policy(payload, **kwargs):
    actor_id = payload.get('actor')
    domain = urllib.parse.urlparse(actor_id).hostname
    if domain not in BLOCKED_FOLLOW_DOMAINS:
        # Raising mrf.Skip isn't necessary but it provides
        # info in the debug logs. Otherwise, you can return:
        raise mrf.Skip("This domain isn't blocked")

    activity_type = payload.get('type')
    object_type = payload.get('object', {}).get('type')

    if object_type == 'Follow' and activity_type == 'Create':
        raise mrf.Discard('Follow from blocked domain')
```

You need to store this code in a Funkwhale plugin. To create one, execute the following:

```{code-block} sh

# Plugin names can only contain ASCII letters, numbers and underscores.
export PLUGIN_NAME="myplugin"
# This is the default path where Funkwhale will look for plugins.
# If you want to use another path, update this path and ensure
# your PLUGINS_PATH is also included in your .env file.
export PLUGINS_PATH="/srv/funkwhale/plugins/"
mkdir -p $PLUGINS_PATH/$PLUGIN_NAME
cd $PLUGINS_PATH/$PLUGIN_NAME

touch __init__.py  # required to make the plugin a valid Python package
# Create the required apps.py file to register our plugin in Funkwhale.
cat > apps.py <<EOF
from django.apps import AppConfig

class Plugin(AppConfig):
    name = "$PLUGIN_NAME"

EOF
```

Once you've created the plugin, put your code in an `mrf_policies.py` file. Place this file inside the plugin directory. Next, enable the plugin in your {file}`.env` file by adding its name to the {attr}`FUNKWHALE_PLUGINS` list. Add this variable if it's not there.

## Test your MRF policy

To make the job of writing and debugging MRF policies easier, we provide a management command.

- List registered MRF policies.

  ::::{tab-set}

  :::{tab-item} Debian
  :sync: debian

  ```{code-block} sh
  venv/bin/funkwhale-manage mrf_check --list
  ```

  :::

  :::{tab-item} Docker
  :sync: docker

  ```{code-block} sh
  sudo docker compose run --rm api funkwhale-manage mrf_check --list
  ```

  :::
  ::::

- Check how your MRF policy handles a follow.

  ::::{tab-set}

  :::{tab-item} Debian
  :sync: debian

  ```{code-block} sh
  export MRF_MESSAGE='{"actor": "https://normal.domain/@alice", "type": "Create", "object": {"type": "Follow"}}'
  echo $MRF_MESSAGE | venv/bin/funkwhale-manage mrf_check inbox - -p blocked_follow_domains
  ```

  :::

  :::{tab-item} Docker
  :sync: docker

  ```{code-block} sh
  export MRF_MESSAGE='{"actor": "https://normal.domain/@alice", "type": "Create", "object": {"type": "Follow"}}'
  echo $MRF_MESSAGE | sudo docker compose run --rm api funkwhale-manage mrf_check inbox - -p blocked_follow_domains
  ```

  ::::

- Check how your MRF handles a problematic follow.

  ::::{tab-set}

  :::{tab-item} Debian
  :sync: debian

  ```{code-block} sh
  export MRF_MESSAGE='{"actor": "https://botdomain.org/@bob", "type": "Create", "object": {"type": "Follow"}}'
  echo $MRF_MESSAGE | venv/bin/funkwhale-manage mrf_check inbox - -p blocked_follow_domains
  ```

  :::

  :::{tab-item} Docker
  :sync: docker

  ```{code-block} sh
  export MRF_MESSAGE='{"actor": "https://botdomain.org/@bob", "type": "Create", "object": {"type": "Follow"}}'
  echo $MRF_MESSAGE | sudo docker compose run --rm api funkwhale-manage mrf_check inbox - -p blocked_follow_domains
  ```

  :::
  ::::

- Check a payload against activity already present in the database. You can find the UUID of an activity by visiting `/api/admin/federation/activity`.

  ::::{tab-set}

  :::{tab-item} Debian
  :sync: debian

  ```{code-block} sh
  export ACTIVITY_UUID="06208aea-c687-4e8b-aefd-22f1c3f76039"
  echo $MRF_MESSAGE | venv/bin/funkwhale-manage mrf_check inbox $ACTIVITY_UUID -p blocked_follow_domains
  ```

  :::

  :::{tab-item} Docker
  :sync: docker

  ```{code-block} sh

  export ACTIVITY_UUID="06208aea-c687-4e8b-aefd-22f1c3f76039"

  echo $MRF_MESSAGE | sudo docker compose run --rm api funkwhale-manage mrf_check inbox $ACTIVITY_UUID -p blocked_follow_domains

  ```

  :::
  ::::

There are extra options for testing MRF policies. Check the command help for more options.

::::{tab-set}

:::{tab-item} Debian
:sync: debian

```{code-block} sh
venv/bin/funkwhale-manage mrf_check --help
```

:::

:::{tab-item} Docker
:sync: docker

```{code-block} sh
sudo docker compose run --rm api funkwhale-manage mrf_check --help
```

:::
::::
