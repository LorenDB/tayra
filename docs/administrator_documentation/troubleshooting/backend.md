# Troubleshoot backend issues

The Funkwhale backend is made up of lots of moving parts. This guide shows you how to troubleshoot and gather information about the most important elements of the backend.

## Tools

If you have access to the Funkwhale backend, you can use logs to get more information about an issue.

- **Reverse proxy logs** – check these logs if you have connectivity issues.

::::{tab-set}

:::{tab-item} Nginx
:sync: nginx

```{code-block} sh
sudo tail -f /var/log/nginx/access.log # Follow the access log
sudo tail -f /var/log/nginx/error.log # Follow the error log
```

:::

:::{tab-item} Apache2
:sync: apache2

```{code-block} sh
sudo tail -f /var/log/apache/access.log # Follow the access log
sudo tail -f /var/log/apache/error.log # Follow the error log
```

::::

- **API logs** – check these if you are having issues with the Funkwhale app, federation, or imports.

::::{tab-set}

:::{tab-item} Debian
:sync: debian

```{code-block} sh
journalctl -xn -u funkwhale-server
```

:::

:::{tab-item} Docker
:sync: docker

```{code-block} sh
sudo docker compose logs -f --tail=50 api # Follow the last 50 messages
```

:::
::::

- **Celery logs** – check these if a federation or import task isn't working.

::::{tab-set}

:::{tab-item} Debian
:sync: debian

```{code-block} sh
journalctl -xn -u funkwhale-worker
```

:::

:::{tab-item} Docker
:sync: docker

```{code-block} sh
sudo docker compose logs -f --tail=50 celery # Follow the last 50 messages
```

:::
::::

## Troubleshoot issues

### API issues

If the API isn't serving audio files, try the following:

- If you’re using Docker, check you have commented out the `MEDIA_ROOT` variable in your `.env` file.
- Check the `_protected/media` block in your webserver points to your media path. This is `/srv/funkwhale/data/media` by default.
- If you’re using the in-place import, check you have configured your media paths. Check the `MUSIC_DIRECTORY_PATH`, `MUSIC_DIRECTORY_SERVE_PATH` and `REVERSE_PROXY_TYPE` variables in your `.env` file. Make sure the webserver can read these directories.

### Import issues

If you're having issues importing files, try the following:

- Check that the file is encoded in a supported format

:::{dropdown} Supported formats

- flac
- ogg
- mp3
- opus
- aac
- m4a
- aiff
- aif

:::

- Make sure your files play in another media player.
- Make sure your files are [tagged correctly](../../user_documentation/libraries/tag_music.md).
- Check the Celery logs for errors during the import.

### Federation issues

If you are having issues accessing federated content, try the following:

- Check that the remote library received your follow request and approved it.
- Trigger a library scan in the Funkwhale frontend.
- Check the Celery logs for errors during the scan.

### Memory tracing

If your Funkwhale server uses more memory than expected, you can check the footprint of requests. This requires a middleware to check memory allocation. To set up this middleware:

1. Add the middleware to your `.env` file.

   ```{code-block} text
   ADDITIONAL_MIDDLEWARES_BEFORE=funkwhale_api.common.middleware.PymallocMiddleware
   ```

2. Enable memory tracing in your `.env` file.

   ```{code-block} text
   PYTHONTRACEMALLOC=1
   ```

3. Restart your Funkwhale server.

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

The middleware prints out the top 25 memory allocations to the API logs. You can use these to see what requests use the most memory.

To disable memory tracing:

1. Remove the middleware from your `.env` file.

   ```{code-block} text
   # ADDITIONAL_MIDDLEWARES_BEFORE=funkwhale_api.common.middleware.PymallocMiddleware
   ```

2. Disable memory tracing in your `.env` file.

   ```{code-block} text
   PYTHONTRACEMALLOC=0
   ```

3. Restart your Funkwhale server.

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

## Get help

If you can't solve the issue yourself, ask the community for help. Check out the [get help](get_help.md) guide for information about where to ask your question and what details to provide.
