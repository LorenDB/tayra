# Import music from your server

You can import music files you have saved on your server. You need to make sure your files have the [required ID3 tags](../user/libraries/content/tag.md). We recommend using [Musicbrainz Picard](https://picard.musicbrainz.org/) for tagging.

Funkwhale supports the following import methods:

- Copy (default) – Funkwhale copies files from your server into the media store.
- In-place import – Funkwhale adds the storage location of your files to the database. This uses less space than the copy method and ensures your collection is always up-to-date.

To see a full list of options, run the command with the `--help` flag.

::::{tab-set}

:::{tab-item} Debian
:sync: debian

```{code-block} sh
venv/bin/funkwhale-manage import_files --help
```

:::

:::{tab-item} Docker
:sync: docker

```{code-block} sh
sudo docker compose run --rm api funkwhale-manage import_files --help
```

:::
::::

```{contents}
:local:
```

## Get demo music

If you don't have music on your server, you can download creative commons music to test imports with. The Funkwhale project provides a collection courtesy of [Jamendo](https://jamendo.com). To download these tracks:

1. Download the shell script.

   ```{parsed-literal}
   curl -L -o download-tracks.sh "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/{sub-ref}`version`/demo/download-tracks.sh"
   ```

2. Download the music list.

   ```{parsed-literal}
   curl -L -o music.txt "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/{sub-ref}`version`/demo/music.txt" chmod +x download-tracks.sh
   ```

3. Run the shell script against the music list to download the tracks.

   ```{code-block} sh
   ./download-tracks.sh music.txt
   ```

This downloads a set compressed albums to your `data/music` directory and unzips them. You can then import these tracks using the methods in this article.

## Find your library ID

You need to create a library before you can import music. Follow the instructions in [Create a library](../user/libraries/create.md) to get started.

Once you've created your library, you can find its ID by following these steps:

1. Visit `https://<yourdomain>/content/libraries/` in your browser. This page contains a list of your libraries.
2. Find the library you want to upload content into. Select {guilabel}`Library details` to open the library details page.
3. Your library's ID is the long string of letters and numbers shown in the URL bar. Copy the content before the first hyphen (`-`).

For example, if your library ID is `769a2bc3-eb1d-4aff-9f84-2c4d80d5c2d1`, copy the `769a2bc3`. You can use this as a shorthand reference for your library.

## Import your music

### Copy files from your server

Once you have your library ID, you can copy content from your server and import it into the library. To do this:

1. Log in to your server and navigate to your Funkwhale directory.

   ```{code-block} sh
   cd /srv/funkwhale
   ```

2. Export your library ID to reference it later. In this example, the library ID is "769a2bc3". Replace this with your library ID.

   ```{code-block} sh
   export LIBRARY_ID="769a2bc3"
   ```

3. Run the `import_files` command to copy your files. In this example, the music is stored in `data/music`. Replace this with your music directory.

   ```{code-block} sh
   venv/bin/funkwhale-manage import_files $LIBRARY_ID "data/music" --recursive --noinput
   ```

Funkwhale copies your files to your media store.

### Access your files in-place

The in-place import method references your files in their current directory. This is useful if you have limited storage space.

#### Link your file directory

We recommend you symbolically link your music directories to `/srv/funkwhale/data/music`. You can then run the `import_files` command from that directory. This means you can use many directories without needing to add to them to your webserver.

::::{tab-set}

:::{tab-item} Debian
:sync: debian

To link your storage directory to the Funkwhale store, use the `ln -s` command. For example, if you have an NFS share at `/media/nfsshare`, you can link it to a folder like this:

```{code-block} sh
ln -s ln -s /media/mynfsshare /srv/funkwhale/data/music/nfsshare
```

You can then run the `import_files` command against `/srv/funkwhale/data/music/nfsshare`.

:::

:::{tab-item} Docker
:sync: docker

On a Docker install you can use bind mounts to reference your storage directory. To do this, you need to add the directory to the `api` and `celeryworker` blocks in your `docker-compose.yml` file. For example, if you have an NFS share at `/media/nfsshare`, you can add the following to your `docker-compose.yml` file:

```{code-block} yaml
celeryworker:
  volumes:
   - ./data/music:/music:ro
   - ./data/media:/app/funkwhale_api/media
   # Add your bind here
   - type: bind
      source: /media/nfsshare
      destination: /srv/funkwhale/data/music/nfsshare

api:
   volumes:
   - ./data/music:/music:ro
   - ./data/media:/app/funkwhale_api/media
   # Add your bind here
   - type: bind
      source: /media/nfsshare
      destination: /srv/funkwhale/data/music/nfsshare
```

You can then run the `import_files` command against `/srv/funkwhale/data/music/nfsshare`.

:::
::::

#### Import your files

To use the in-place import method, follow these steps:

::::{tab-set}

:::{tab-item} Debian
:sync: debian

1. Log in to your server and navigate to your Funkwhale directory.

   ```{code-block} sh
   cd /srv/funkwhale
   ```

2. Add your storage location to your `.env` file if you don't want to link it to the Funkwhale store. See the [in-place import configuration variables](configuration/env_file.md#in-place-import-configuration) for more information.
3. Export your library ID to reference it later. In this example, the library ID is "769a2bc3". Replace this with your library ID.

   ```{code-block} sh
   export LIBRARY_ID="769a2bc3"
   ```

4. Run your import command against your music storage directory. In this example, the storage directory is `/srv/funkwhale/data/music/nfsshare`. Replace this with your storage directory.

   ```{code-block} sh
   venv/bin/funkwhale-manage import_files $LIBRARY_ID "/srv/funkwhale/data/music/nfsshare/" --recursive --noinput --in-place
   ```

Funkwhale imports the music in your storage directory into the specified library.

:::

:::{tab-item} Docker
:sync: docker

1. Add your storage location to your `.env` file if you don't want to bind it to the Funkwhale store. See the [in-place import configuration variables](configuration/env_file.md#in-place-import-configuration) for more information.
2. Run your import command against your music storage directory:

   ```{code-block} sh
   sudo docker compose run --rm api funkwhale-manage import_files $LIBRARY_ID "/srv/funkwhale/data/music/nfsshare/" --recursive --noinput --in-place
   ```

Funkwhale imports the music in your storage directory into the specified library.

:::
::::

### Album art

Funkwhale attempts to import album art for your music library. The import process checks for the following.

1. The cover embedded in the audio files (works with FLAC and MP3 files).
2. A `cover.jpg` or `cover.png` in the the track's directory.
3. An `mbid` in the file's tags. If there is an `mbid`, the import process tries to fetch cover art from Musicbrainz.

## Watch for filesystem changes

You can run the `import_files` command any time you add new files or update files. For larger collections, this may not be practical. To watch for changes, run the `import_files` command with the `--watch` flag. This instructs the `import_files` command to watch for filesystem events and update your database when something changes.

The `--watch` flag performs the following actions when it detects a change:

- File created – imports the track.
- File moved – updates the location of the track in the database.
- File metadata updated – updates the track metadata in the database.
- File deleted – removes the file from the database.

:::{dropdown} Watched metadata

The `import_files --watch` command watches for changes to the following metadata fields:

- Track mbid
- Track title
- Track position and disc number
- Track license and copyright
- Track genre
- Album cover
- Album title
- Album mbid
- Album release date
- Artist name
- Artist mbid
- Album artist name
- Album artist mbid

:::

::::{tab-set}

:::{tab-item} Debian
:sync: debian

```{code-block} sh
venv/bin/funkwhale-manage import_files $LIBRARY_ID "/srv/funkwhale/data/music/nfsshare/" --recursive --noinput --in-place --watch
```

:::

:::{tab-item} Docker
:sync: docker

```{code-block} sh
sudo docker compose run --rm api funkwhale-manage import_files $LIBRARY_ID "/srv/funkwhale/data/music/nfsshare/" --recursive --noinput --in-place --watch
```

:::
::::

## Prune dangling metadata

Funkwhale doesn't delete track metadata when you delete a track. This is useful if you want to delete a file but keep a record of a track for created playlists or favorites.

If you want to remove the file's metadata when you delete the file, run `import_files` with the `--prune` flag. This flag removes the metadata of any

```{note}
You can use the `--prune` flag with the `--watch` flag. This means Funkwhale removes the metadata of referenced files you delete from your storage.
```

::::{tab-set}

:::{tab-item} Debian
:sync: debian

```{code-block} sh
venv/bin/funkwhale-manage import_files $LIBRARY_ID "/srv/funkwhale/data/music/nfsshare/" --recursive --noinput --in-place --watch --prune
```

:::

:::{tab-item} Docker
:sync: docker

```{code-block} sh
sudo docker compose run --rm api funkwhale-manage import_files $LIBRARY_ID "/srv/funkwhale/data/music/nfsshare/" --recursive --noinput --in-place --watch --prune
```

:::
::::
