# Fix uploads

Use the `fix_uploads` command to let Funkwhale sort out common issues with your audio files.

## Commands

### Fix mimetypes

Check and fix file mimetypes with the `--mimetype` flag. This helps prevent issues with serving music files.

````{tabbed} Debian

```{code} bash
poetry run python manage.py fix_uploads --mimetype
```

````

````{tabbed} Docker

```{code} bash
docker-compose run --rm api python manage.py fix_uploads --mimetype
```

````

### Fix bitrate and duration

Check and fix bitrate and duration with the `--audio-data` flag. This process can take a long time as it needs to access all files.

````{tabbed} Debian

```{code} bash
poetry run python manage.py fix_uploads --audio-data
```

````

````{tabbed} Docker

```{code} bash
docker-compose run --rm api python manage.py fix_uploads --audio-data
```

````

### Fix file size

Check and fix the file size with the `--size` flag.

````{tabbed} Debian

```{code} bash
poetry run python manage.py fix_uploads --size
```

````

````{tabbed} Docker

```{code} bash
docker-compose run --rm api python manage.py fix_uploads --size
```

````

### Fix file checksums

Check and fix file checksums with the `--checksum` flag.

````{tabbed} Debian

```{code} bash
poetry run python manage.py fix_uploads --checksum
```

````

````{tabbed} Docker

```{code} bash
docker-compose run --rm api python manage.py fix_uploads --checksum
```

````

### Change command batch size

Choose the batch size you want to process with the `--batch-size` or -`s` flag. Smaller batches process faster. Defaults to `1000`.

````{tabbed} Debian

```{code} bash
poetry run python manage.py fix_uploads --batch-size 500
```

````

````{tabbed} Docker

```{code} bash
docker-compose run --rm api python manage.py fix_uploads --batch-size 500
```

````
