# Delete obsolete files from the database

Funkwhale keeps references to files imported using the in-place method. If you move or remove these, it invalidates the reference and Funkwhale can't serve the files.

Use the `check_inplace_files` command to check the database for invalid references. This command loops through all in-place imports and checks if the file is accessible. If the file isn't accessible, the command deletes the database object.

```{warning}
Running `check_inplace_files` with the `--no-dry-run` flag is irreversible. Make sure you [back up your data](../upgrade/backup.md).
```

To ensure you don't remove data by accident, this command runs in dry run mode by default. In dry run mode, the command lists the items it will delete. Run the command with the `--no-dry-run` flag to perform the pruning action.

::::{tab-set}

:::{tab-item} Debian
:sync: debian

```{code-block} sh
venv/bin/funkwhale-manage check_inplace_files
```

:::

:::{tab-item} Docker
:sync: docker

```{code-block} sh
sudo docker compose run --rm api funkwhale-manage check_inplace_files
```

:::
::::
