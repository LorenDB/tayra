# Delete obsolete files from the database

Funkwhale keeps references to files imported using the in-place method. If you move or remove these, it invalidates the reference and Funkwhale can't serve the files.

Use the `check_inplace_files` command to check the database for invalid references. This command loops through all in-place imports and checks if the file is accessible. If the file isn't accessible, the command deletes the database object.

```{warning}
Running `check_inplace_files` with the `--no-dry-run` flag is irreversible. Make sure you [back up your data](../upgrade_docs/backup.md).
```

To ensure you don't remove data by accident, this command runs in dry run mode by default. In dry run mode, the command lists the items it will delete. Run the command with the `--no-dry-run` flag to perform the pruning action.

````{tabbed} Debian

```{code} bash
poetry run python manage.py check_inplace_files
```

````

````{tabbed} Docker

```{code} bash
docker-compose run --rm api python manage.py check_inplace_files
```

````
