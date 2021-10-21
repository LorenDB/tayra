Built-in plugins
================

Funkwhale by default includes some plugins each user can configure and use.
Plugins can be configured in your settings with the :guilabel:`Manage plugins` button.


.. _scrobbler-plugin:

Scrobbler
---------

The Scrobbler plugin allows you to submit your listenings to Audioscrobbler
compatible services, such as `Last.fm <https://www.last.fm/>`_ or free alternatives like
`Libre.fm <https://libre.fm/>`_ or `ListenBrainz <https://listenbrainz.org>`_.
To use this plugin enable it and configure it for the scrobbler service of your choice as
described below. Note that you need an account for the respective service.

**Last.fm:** This is the default service being used. Leave the scrobble service URL empty or set it
to ``http://post.audioscrobbler.com`` and set your Last.fm username and password as the scrobbler
username and scrobbler password.

.. note::

    If you want to scrobble to Last.fm, you or your server's administrator will need to create a
    `Last.fm API account <https://www.last.fm/api/account/create>`_ and add
    the following two variables to your Funkwhale server ``.env`` file::

        FUNKWHALE_PLUGIN_SCROBBLER_LASTFM_API_KEY=apikey
        FUNKWHALE_PLUGIN_SCROBBLER_LASTFM_API_SECRET=apisecret

**Libre.fm:** To use Libre.fm set the scrobble service URL to ``https://turtle.libre.fm/`` and set
your libre.fm username and password as the scrobbler username and scrobbler password.

**ListenBrainz:** To use ListenBrainz set the scrobble service URL to ``http://proxy.listenbrainz.org/``.
For the username use your ListenBrainz username, for the password use your ListenBrainz user token.
You can find the user token on your `ListenBrainz profile <https://listenbrainz.org/profile/>`_.

.. note::

    It is recommended to use the :ref:`ListenBrainz plugin <listenbrainz-plugin>` instead of the
    Scrobbler plugin. The ListenBrainz plugin uses the native ListenBrainz API and submits more
    details for the listened songs, while the Scrobbler plugin uses the legacy Audioscrobbler API.


.. _listenbrainz-plugin:

ListenBrainz
------------

This plugin allows you to submit your listenings to `ListenBrainz <https://listenbrainz.org>`_,
a free service to track your music listening habits. To use ListenBrainz you need to
`sign in <https://listenbrainz.org/login/>`_ with a `MusicBrainz account <https://musicbrainz.org/>`_.
If you don't have a MusicBrainz account, you can `create one <https://musicbrainz.org/register>`_.

To submit your listenings from Funkwhale to ListenBrainz enable the plugin and set your
ListenBrainz user token. You can find the user token on your
`ListenBrainz profile <https://listenbrainz.org/profile/>`_.


.. _maloja-plugin:

Maloja
------

This plugin allows you to submit your listenings to your own `Maloja <https://github.com/krateng/maloja>`_
instance. Maloja is a personal scrobble service similar to Last.fm or ListenBrainz, but only for yourself.
You can self-host your own Maloja instance, please see the
`Maloja documentation <https://github.com/krateng/maloja#how-to-install>`_ for details.

To submit your listenings to your own Maloja instance enable the plugin, then set the Maloja server URL
to the URL of your instance and enter your Maloja API key. An API key is created on initial setup
of your Maloja instance, but you can setup additional API keys in the file ``authenticated_machines.tsv`` in the
``/etc/maloja/clients`` folder.
