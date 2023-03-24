# Optimize memory usage

Funkwhale has a reasonable memory footprint. If you're running Funkwhale on a limited device, you can use these tweaks to reduce the footprint.

## Reduce workers concurrency

Funkwhale uses Celery to handle asynchronous tasks. By default, Celery spawns a worker per CPU core. This can lead to higher memory usage.

You can set the number of workers using the `CELERYD_CONCURRENCY` variable in your `.env` file. For example, a value of `CELERYD_CONCURRENCY=1` spawns a single worker.

```{note}
Reducing the number of celery workers slows down the handling of asynchronous tasks. On larger instances, this can cause performance problems.
```

## Switch to solo pool execution

Celery uses a `prefork` pool by default. This enables the server to process many tasks at the same time. You can switch to a `solo` pool which handles tasks one at a time. This reduces memory overhead but removes the ability to process tasks concurrently.

::::{tab-set}

:::{tab-item} Debian
:sync: debian

1. Open your `funkwhale-worker` unit file in an editor.

   ```{code-block} sh
   sudo nano /etc/systemd/system/funkwhale-worker.service
   ```

2. Add the `--pool=solo` flag to the `ExecStart` line of your unit file.

   ```{code-block} text
   ExecStart=/srv/funkwhale/venv/bin/celery \
      --app funkwhale_api.taskapp \
      --pool solo \
      worker \
      --loglevel INFO \
      --concurrency=${CELERYD_CONCURRENCY}
   ```

3. Restart the Celery service.

   ```{code-block} sh
   sudo systemctl restart funkwhale-worker.service
   ```

:::

:::{tab-item} Docker
:sync: docker

1. Add the `--pool=solo` flag to the `celerybeat` command in `docker-compose.yml`.

   ```{code-block} yaml
   celerybeat:
   …
   command: celery -A --pool=solo funkwhale_api.taskapp beat --pidfile= -l INFO
   ```

2. Restart Celery.

   ```{code-block} sh
   sudo docker compose restart celerybeat
   ```

:::
::::
