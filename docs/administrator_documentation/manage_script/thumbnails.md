# Regenerate thumbnails

We increased the quality of thumbnails from 70px to 95px in Funkwhale 1.0. This action removes visual artifacts that affect lower quality thumbnails. You can run the `manage.py` script to generate new thumbnails. If you want to keep thumbnails at their original quality, add `THUMBNAIL_JPEG_RESIZE_QUALITY=70` to your `.env` file.

```{note}
If you're using S3 storage, the `__sized__` folder is located in your S3 bucket.
```

To generate new thumbnails:

```{tabbed} Debian

1. SSH into your Funkwhale server.
2. Navigate to your Funkwhale directory.

      ```{code} bash
      cd  /srv/funkwhale
      ```

3. Delete the `__sized__` directory inside your `MEDIA_ROOT` directory. By default this is `/srv/funkwhale/data/media`. This directory contains the current thumbnails.

      ```{code} bash
      rm -r __sized__/
      ```

4. Run the `manage.py` script to regenerate the thumbnails.

      ```{code} bash
      poetry run python manage.py fw media generate-thumbnails
      ```

```

```{tabbed} Docker

1. SSH into your Funkwhale server.
2. Navigate to your Funkwhale directory.

      ```{code} bash
      cd  /srv/funkwhale/
      ```

3. Delete the `__sized__` directory inside your `MEDIA_ROOT` directory. By default this is `/srv/funkwhale/data/media`. This directory contains the current thumbnails.

      ```{code} bash
      rm -r data/media/__sized__/
      ```

4. Run the `manage.py` script to regenerate the thumbnails.

      ```{code} bash
      docker-compose run --rm api python manage.py fw media generate-thumbnails
      ```

```

The script generates new thumbnails for all album and artist art on your pod.
