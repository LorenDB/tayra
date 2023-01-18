# Fix uploads

Use the `fix_uploads` command to let Funkwhale sort out common issues with your audio files.

## Commands

### Fix mimetypes

Check and fix file mimetypes with the `--mimetype` flag. This helps prevent issues with serving music files.

::::{tab-set}

:::{tab-item} Debian
:sync: debian

```{code-block} sh
venv/bin/funkwhale-manage fix_uploads --mimetype
```

:::

:::{tab-item} Docker
:sync: docker

```{code-block} sh
sudo docker compose run --rm api funkwhale-manage fix_uploads --mimetype
```

:::
::::

### Fix bitrate and duration

Check and fix bitrate and duration with the `--audio-data` flag. This process can take a long time as it needs to access all files.

::::{tab-set}

:::{tab-item} Debian
:sync: debian

```{code-block} sh
venv/bin/funkwhale-manage fix_uploads --audio-data
```

:::

:::{tab-item} Docker
:sync: docker

```{code-block} sh
sudo docker compose run --rm api funkwhale-manage fix_uploads --audio-data
```

:::
::::

### Fix file size

Check and fix the file size with the `--size` flag.

::::{tab-set}

:::{tab-item} Debian
:sync: debian

```{code-block} sh
venv/bin/funkwhale-manage fix_uploads --size
```

:::

:::{tab-item} Docker
:sync: docker

```{code-block} sh
sudo docker compose run --rm api funkwhale-manage fix_uploads --size
```

:::
::::

### Fix file checksums

Check and fix file checksums with the `--checksum` flag.

::::{tab-set}

:::{tab-item} Debian
:sync: debian

```{code-block} sh
venv/bin/funkwhale-manage fix_uploads --checksum
```

:::

:::{tab-item} Docker
:sync: docker

```{code-block} sh
sudo docker compose run --rm api funkwhale-manage fix_uploads --checksum
```

:::
::::

### Change command batch size

Choose the batch size you want to process with the `--batch-size` or -`s` flag. Smaller batches process faster. Defaults to `1000`.

::::{tab-set}

:::{tab-item} Debian
:sync: debian

```{code-block} sh
venv/bin/funkwhale-manage fix_uploads --batch-size 500
```

:::

:::{tab-item} Docker
:sync: docker

```{code-block} sh
sudo docker compose run --rm api funkwhale-manage fix_uploads --batch-size 500
```

:::
::::
