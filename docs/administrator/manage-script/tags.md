# Add artist and album tags from track metadata

Funkwhale extracts track tags from the file's metadata. Funkwhale applies these tags to the track's album and artist by running a check every few days. You can run the process at any time using the `funkwhale-manage` command line interface.

The command performs the following actions:

1. Finds all local artists or albums with no tags.
2. Gets all the tags associated with the album/artist's tracks.
3. Applies the track's tags to the album/artist.

## Add tags to albums

To add tags to untagged albums:

::::{tab-set}

:::{tab-item} Debian
:sync: debian

1. SSH into your Funkwhale server.
2. Navigate to the Funkwhale directory.

   ```{code-block} sh
   cd /srv/funkwhale
   ```

3. Run the `funkwhale-manage` command line interface to generate tags for untagged albums.

   ```{code-block} sh
   venv/bin/funkwhale-manage fw albums add-tags-from-tracks
   ```

:::

:::{tab-item} Docker
:sync: docker

1. SSH into your Funkwhale server.
2. Navigate to the Funkwhale directory.

   ```{code-block} sh
   cd /srv/funkwhale
   ```

3. Run the `funkwhale-manage` command line interface to generate tags for untagged albums.

   ```{code-block} sh
   sudo docker compose run --rm api funkwhale-manage fw albums add-tags-from-tracks
   ```

:::
::::

## Add tags to artists

To add tags to untagged artists:

::::{tab-set}

:::{tab-item} Debian
:sync: debian

1. SSH into your Funkwhale server.
2. Navigate to the Funkwhale directory.

   ```{code-block} sh
   cd /srv/funkwhale
   ```

3. Run the `funkwhale-manage` command line interface to generate tags for untagged artists.

   ```{code-block} sh
   venv/bin/funkwhale-manage fw artists add-tags-from-tracks
   ```

:::

:::{tab-item} Docker
:sync: docker

1. SSH into your Funkwhale server.
2. Navigate to the Funkwhale directory.

   ```{code-block} sh
   cd /srv/funkwhale
   ```

3. Run the `funkwhale-manage` command line interface to generate tags for untagged artists.

   ```{code-block} sh
   sudo docker compose run --rm api funkwhale-manage fw artists add-tags-from-tracks
   ```

:::
::::
