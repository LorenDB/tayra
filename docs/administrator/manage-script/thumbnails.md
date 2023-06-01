# Regenerate thumbnails

We increased the quality of thumbnails from 70px to 95px in Funkwhale 1.0. This action removes visual artifacts that affect lower quality thumbnails. You can run the `funkwhale-manage` command line interface to generate new thumbnails. If you want to keep thumbnails at their original quality, add `THUMBNAIL_JPEG_RESIZE_QUALITY=70` to your `.env` file.

```{note}
If you're using S3 storage, the `__sized__` folder is located in your S3 bucket.
```

To generate new thumbnails:

::::{tab-set}

:::{tab-item} Debian
:sync: debian

1. SSH into your Funkwhale server.
2. Navigate to your Funkwhale directory.

   ```{code-block} sh
   cd  /srv/funkwhale
   ```

3. Delete the `__sized__` directory inside your `MEDIA_ROOT` directory. By default this is `/srv/funkwhale/data/media`. This directory contains the current thumbnails.

   ```{code-block} sh
   rm -r __sized__/
   ```

4. Run the `funkwhale-manage` command line interface to regenerate the thumbnails.

   ```{code-block} sh
   venv/bin/funkwhale-manage fw media generate-thumbnails
   ```

:::

:::{tab-item} Docker
:sync: docker

1. SSH into your Funkwhale server.
2. Navigate to your Funkwhale directory.

   ```{code-block} sh
   cd  /srv/funkwhale/
   ```

3. Delete the `__sized__` directory inside your `MEDIA_ROOT` directory. By default this is `/srv/funkwhale/data/media`. This directory contains the current thumbnails.

   ```{code-block} sh
   rm -r data/media/__sized__/
   ```

4. Run the `funkwhale-manage` command line interface to regenerate the thumbnails.

   ```{code-block} sh
   sudo docker compose run --rm api funkwhale-manage fw media generate-thumbnails
   ```

:::
::::

The script generates new thumbnails for all album and artist art on your pod.
