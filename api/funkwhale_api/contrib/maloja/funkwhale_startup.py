from config import plugins

PLUGIN = plugins.get_plugin_config(
    name="maloja",
    label="Maloja",
    description="A plugin that allows you to submit your listens to your Maloja server.",
    homepage="https://docs.funkwhale.audio/users/builtinplugins.html#maloja-plugin",
    version="0.1",
    user=True,
    conf=[
        {"name": "server_url", "type": "text", "label": "Maloja server URL"},
        {"name": "api_key", "type": "text", "label": "Your Maloja API key"},
    ],
)
