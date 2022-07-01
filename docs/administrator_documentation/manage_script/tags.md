# Add artist and album tags from track metadata

Funkwhale extracts track tags from the file's metadata. Funkwhale applies these tags to the track's album and artist by running a check every few days. You can run the process at any time using the `manage.py` script.

The command performs the following actions:

1. Finds all local artists or albums with no tags.
2. Gets all the tags associated with the album/artist's tracks.
3. Applies the track's tags to the album/artist.

## Add tags to albums

To add tags to untagged albums:

```{tabbed} Debian

1. SSH into your Funkwhale server.
2. Navigate to the Funkwhale directory.

      ```{code} bash
      cd /srv/funkwhale
      ```

3. Run the `manage.py` script to generate tags for untagged albums.

      ```{code} bash
      poetry run python manage.py fw albums add-tags-from-tracks
      ```

```

```{tabbed} Docker

1. SSH into your Funkwhale server.
2. Navigate to the Funkwhale directory.

      ```{code} bash
      cd /srv/funkwhale
      ```

3. Run the `manage.py` script to generate tags for untagged albums.

      ```{code} bash
      docker-compose run --rm api python manage.py fw albums add-tags-from-tracks
      ```

```

## Add tags to artists

To add tags to untagged artists:

```{tabbed} Debian

1. SSH into your Funkwhale server.
2. Navigate to the Funkwhale directory.

      ```{code} bash
      cd /srv/funkwhale
      ```

3. Run the `manage.py` script to generate tags for untagged artists.

      ```{code} bash
      poetry run python manage.py fw artists add-tags-from-tracks
      ```

```

```{tabbed} Docker

1. SSH into your Funkwhale server.
2. Navigate to the Funkwhale directory.

      ```{code} bash
      cd /srv/funkwhale
      ```

3. Run the `manage.py` script to generate tags for untagged artists.

      ```{code} bash
      docker-compose run --rm api python manage.py fw artists add-tags-from-tracks
      ```

```
