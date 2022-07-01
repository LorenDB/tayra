# Prune your Funkwhale library

Funkwhale doesn't delete data objects from the database when you delete a file. This is because they might exist in users' playlists, favorites, and listening history. These objects might also be present in another user's private libraries.

Sometimes you may want to clear out dangling metadata. For example, if you import a lot of files with incorrect tags and then delete them.

To help with this, the {file}`manage.py` script includes commands to prune dangling metadata from your database. All prune commands are available under the python manage.py prune_library namespace. To ensure you don't remove data by accident, all commands run in dry run mode by default. Run commands with the `--no-dry-run` flag to perform the pruning action.

```{warning}
Running `prune_library` commands with the `--no-dry-run` flag is irreversible. Make sure you [back up your data](../upgrade_docs/backup.md).
```

## Commands

### Prune tracks with no associated uploads

````{tabbed} Debian

```bash
poetry run python manage.py prune_library --tracks
```

````

````{tabbed} Docker

```bash
docker-compose run --rm api python manage.py prune_library --tracks
```

````

### Prune albums with no associated tracks

````{tabbed} Debian

```{code} bash
poetry run python manage.py prune_library --albums
```

````

````{tabbed} Docker

```{code} bash
docker-compose run --rm api python manage.py prune_library --albums
```

````

### Prune artists with no associated tracks or albums

````{tabbed} Debian

```{code} bash
poetry run python manage.py prune_library --artists
```

````

````{tabbed} Docker

```{code} bash
docker-compose run --rm api python manage.py prune_library --artists
```

````

### Prune all tracks, albums, and artist without associated data

````{tabbed} Debian

```{code} bash
poetry run python manage.py prune_library --tracks --albums --artists
```

````

````{tabbed} Docker

```{code} bash
docker-compose run --rm api python manage.py prune_library --tracks --albums --artists
```

````

There are extra options for pruning your database. Check the command help for more options.

````{tabbed} Debian

```{code} bash
poetry run python manage.py prune_library --help
```

````

````{tabbed} Docker

```{code} bash
docker-compose run --rm api python manage.py prune_library --help
```

````

```{note}
The command excludes tracks that are in users' favorites, playlists, and listen history. To include these tracks, add the corresponding `ignore` flag:

- `--ignore-favorites`
- `--ignore-playlists`
- `--ignore-listenings`
```
