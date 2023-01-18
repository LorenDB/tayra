# Customize your environment file

Your `.env` (environment) file contains variables you can change to customize your pod. You can change these variables at any time to alter how your pod runs.

You need to restart your Funkwhale services after changing your `.env` file.

::::{tab-set}

:::{tab-item} Debian
:sync: debian

```{code-block} sh
sudo systemctl restart funkwhale.target
```

:::

:::{tab-item} Docker
:sync: docker

```{code-block} sh
sudo docker compose restart
```

:::
::::

## Variables

````{important}

Some environment variables accept a URL as a value. To encode URLs and avoid problems with special characters, use `urllib.parse` on your URL value.

   ```py
   python3 -c 'import urllib.parse; print(urllib.parse.quote_plus("p@ssword"))
   ```

   ```{seealso}
      The [django-environ documentation](https://github.com/joke2k/django-environ/blob/main/docs/tips.rst#using-unsafe-characters-in-urls).
   ```

````

### Pod configuration

```{eval-rst}
.. autodata:: config.settings.common.FUNKWHALE_HOSTNAME
   :annotation: = mypod.audio
.. autodata:: config.settings.common.FUNKWHALE_PROTOCOL
   :annotation: =  https
```

### Database and redis configuration

```{eval-rst}
.. autodata:: config.settings.common.DATABASE_URL
   :annotation: = postgresql://<user>:<password>@<host>:<port>/<database>
.. autodata:: config.settings.common.DB_CONN_MAX_AGE
.. autodata:: config.settings.common.CACHE_URL
   :annotation: = redis://<host>:<port>/<database>
.. autodata:: config.settings.common.CELERY_BROKER_URL
   :annotation: = redis://127.0.0.1:6379/0
```

### Accounts and registration

```{eval-rst}

.. autodata:: config.settings.common.ACCOUNT_EMAIL_VERIFICATION_ENFORCE
   :annotation: = true
.. autodata:: config.settings.common.USERS_INVITATION_EXPIRATION_DAYS
   :annotation: = 7
.. autodata:: config.settings.common.DISABLE_PASSWORD_VALIDATORS
   :annotation: = true
.. autodata:: config.settings.common.ACCOUNT_USERNAME_BLACKLIST
   :annotation: = test,funkwhale
```

```{py:data} LDAP_ENABLED
---
value: false
---

Whether to enable LDAP authentication.

See {doc}`/administrator_documentation/configuration_docs/ldap` for more information.

```

### Media storage and serving configuration

```{eval-rst}

.. autodata:: config.settings.common.MEDIA_URL
   :annotation: = https://mypod.audio/media/
.. autodata:: config.settings.common.MEDIA_ROOT
   :annotation: = /srv/funkwhale/data/media
.. autodata:: config.settings.common.PROXY_MEDIA
   :annotation: = true
.. autodata:: config.settings.common.EXTERNAL_MEDIA_PROXY_ENABLED
   :annotation: = false
.. autodata:: config.settings.common.ATTACHMENTS_UNATTACHED_PRUNE_DELAY
   :annotation: = true
.. autodata:: config.settings.common.REVERSE_PROXY_TYPE
   :annotation: = nginx
.. autodata:: config.settings.common.PROTECT_FILES_PATH
   :annotation: = /_protected
.. py:data:: NGINX_MAX_BODY_SIZE
   :value: 100M

   Controls the maximum size of file that users can upload.

   .. note::
      You can control how much total storage a user can access with the :term:`Upload Quota` setting.

```

### S3 storage configuration

```{eval-rst}

.. autodata:: config.settings.common.AWS_QUERYSTRING_AUTH
.. autodata:: config.settings.common.AWS_QUERYSTRING_EXPIRE
.. autodata:: config.settings.common.AWS_ACCESS_KEY_ID
.. autodata:: config.settings.common.AWS_SECRET_ACCESS_KEY
.. autodata:: config.settings.common.AWS_STORAGE_BUCKET_NAME
.. autodata:: config.settings.common.AWS_S3_CUSTOM_DOMAIN
.. autodata:: config.settings.common.AWS_S3_ENDPOINT_URL
   :annotation: = https://minio.mydomain.com
.. autodata:: config.settings.common.AWS_S3_REGION_NAME
   :annotation: = eu-west-2
.. autodata:: config.settings.common.AWS_LOCATION
   :annotation: = funkwhale_music

```

### In-place import configuration

```{eval-rst}

.. autodata:: config.settings.common.MUSIC_DIRECTORY_PATH
   :annotation: = /srv/funkwhale/data/music
.. autodata:: config.settings.common.MUSIC_DIRECTORY_SERVE_PATH
   :annotation: = /srv/funkwhale/data/music

```

### API configuration

```{eval-rst}

.. autodata:: config.settings.common.THROTTLING_ENABLED
.. autodata:: config.settings.common.THROTTLING_RATES
   :annotation: = signup=5/d,password-reset=2/d,anonymous-reports=5/d

```

See [Rate limit API endpoints](rate-limiting.md) for a list of available endpoints and their default limits.

```{eval-rst}

.. autodata:: config.settings.common.ADMIN_URL
.. autodata:: config.settings.common.EXTERNAL_REQUESTS_VERIFY_SSL
.. autodata:: config.settings.common.EXTERNAL_REQUESTS_TIMEOUT

```

### Federation configuration

```{eval-rst}

.. autodata:: config.settings.common.FEDERATION_OBJECT_FETCH_DELAY
.. autodata:: config.settings.common.FEDERATION_DUPLICATE_FETCH_DELAY

```

### Metadata configuration

```{eval-rst}

.. autodata:: config.settings.common.TAGS_MAX_BY_OBJ
.. autodata:: config.settings.common.MUSICBRAINZ_HOSTNAME
.. autodata:: config.settings.common.MUSICBRAINZ_CACHE_DURATION

```

### Channels and podcast configuration

```{eval-rst}

.. autodata:: config.settings.common.PODCASTS_RSS_FEED_REFRESH_DELAY
.. autodata:: config.settings.common.PODCASTS_RSS_FEED_MAX_ITEMS
.. autodata:: config.settings.common.PODCASTS_THIRD_PARTY_VISIBILITY

```

### Subsonic configuration

```{eval-rst}

.. autodata:: config.settings.common.SUBSONIC_DEFAULT_TRANSCODING_FORMAT

```

### Email configuration

```{eval-rst}

.. autodata:: config.settings.common.EMAIL_CONFIG
   :annotation: = consolemail://
.. autodata:: config.settings.common.DEFAULT_FROM_EMAIL
   :annotation: = Funkwhale <noreply@yourdomain>
.. autodata:: config.settings.common.EMAIL_SUBJECT_PREFIX

```

### Plugin configuration

```{eval-rst}

.. autodata:: config.settings.common.FUNKWHALE_PLUGINS_PATH

```

```{py:data} FUNKWHALE_PLUGINS
---
value: "['funkwhale_api.contrib.scrobbler', 'funkwhale_api.contrib.listenbrainz', 'funkwhale_api.contrib.maloja']"
---

List of Funkwhale plugins to load.
```

### Other settings

```{eval-rst}

.. autodata:: config.settings.common.INSTANCE_SUPPORT_MESSAGE_DELAY
.. autodata:: config.settings.common.FUNKWHALE_SUPPORT_MESSAGE_DELAY
.. autodata:: config.settings.common.MIN_DELAY_BETWEEN_DOWNLOADS_COUNT
.. autodata:: config.settings.common.MARKDOWN_EXTENSIONS
.. autodata:: config.settings.common.LINKIFIER_SUPPORTED_TLDS
.. autodata:: config.settings.common.LOGLEVEL
   :annotation: = info

```
