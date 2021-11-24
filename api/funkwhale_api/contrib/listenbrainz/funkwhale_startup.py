from config import plugins


PLUGIN = plugins.get_plugin_config(
    name="listenbrainz",
    label="ListenBrainz",
    description="A plugin that allows you to submit your listens to ListenBrainz.",
    homepage="https://docs.funkwhale.audio/users/builtinplugins.html#listenbrainz-plugin",  # noqa
    version="0.2",
    user=True,
    conf=[
        {
            "name": "user_token",
            "type": "text",
            "label": "Your ListenBrainz user token",
            "help": "You can find your user token in your ListenBrainz profile at https://listenbrainz.org/profile/",
        }
    ],
)
