# Update in-place location reference for S3

If you've moved your content from a local disk to S3 storage, you need to update the location of any files you imported using `--in-place`. To ensure you don't update entries by accident, all commands run in dry run mode by default. Run commands with the `--no-dry-run` flag to update the references.

:::{note}
This command doesn't move files. It only updates the location of the file to its S3 location based on [the S3 settings in your environment file](/administrator/configuration/object-storage).
:::

:::{list-table} Arguments
:header-rows: 1

- - Argument
  - Description
- - `source`
  - The source directory of your in-place import.

    If no `source` is specified, all in-place imported tracks are updated.

- - `target`
  - The subdirectory in the S3 bucket where the files are now located.

    If no `target` is specified, the current path of the file is used.

:::

## Examples

### Update all in-place imports

::::{tab-set}

:::{tab-item} Debian
:sync: debian

1. SSH into your Funkwhale server.
2. Navigate to the Funkwhale directory.

   ```{code-block} console
   $ cd /srv/funkwhale
   ```

3. Run the `funkwhale-manage` command line interface to update your in-place imports.

   ```{code-block} console
   $ venv/bin/funkwhale-manage fw inplace_to_s3 --no-dry-run
   ```

:::

:::{tab-item} Docker
:sync: docker

1. SSH into your Funkwhale server.
2. Navigate to the Funkwhale directory.

   ```{code-block} console
   $ cd /srv/funkwhale
   ```

3. Run the `funkwhale-manage` command line interface to update your in-place imports.

   ```{code-block} console
   $ sudo docker compose run --rm api funkwhale-manage inplace_to_s3 --no-dry-run
   ```

:::
::::

### Update in-place imports from a specific directory

::::{tab-set}

:::{tab-item} Debian
:sync: debian

1. SSH into your Funkwhale server.
2. Navigate to the Funkwhale directory.

   ```{code-block} console
   $ cd /srv/funkwhale
   ```

3. Run the `funkwhale-manage` command line interface to update your in-place imports.

   ```{code-block} console
   $ venv/bin/funkwhale-manage fw inplace_to_s3 --source "/music" --no-dry-run
   ```

:::

:::{tab-item} Docker
:sync: docker

1. SSH into your Funkwhale server.
2. Navigate to the Funkwhale directory.

   ```{code-block} console
   $ cd /srv/funkwhale
   ```

3. Run the `funkwhale-manage` command line interface to update your in-place imports.

   ```{code-block} console
   $ sudo docker compose run --rm api funkwhale-manage inplace_to_s3 --source "/music" --no-dry-run
   ```

:::
::::

All in-place imports in the `/music` folder are updated to reference the `/music` subdirectory in your S3 bucket.

### Reference a different target subdirectory

::::{tab-set}

:::{tab-item} Debian
:sync: debian

1. SSH into your Funkwhale server.
2. Navigate to the Funkwhale directory.

   ```{code-block} console
   $ cd /srv/funkwhale
   ```

3. Run the `funkwhale-manage` command line interface to update your in-place imports.

   ```{code-block} console
   $ venv/bin/funkwhale-manage fw inplace_to_s3 --source "/music" --target "/new_import" --no-dry-run
   ```

:::

:::{tab-item} Docker
:sync: docker

1. SSH into your Funkwhale server.
2. Navigate to the Funkwhale directory.

   ```{code-block} console
   $ cd /srv/funkwhale
   ```

3. Run the `funkwhale-manage` command line interface to update your in-place imports.

   ```{code-block} console
   $ sudo docker compose run --rm api funkwhale-manage inplace_to_s3 --source "/music" --target "/new_import" --no-dry-run
   ```

:::
::::

All in-place imports in the `/music` folder are updated to reference the `/new_import` subdirectory in your S3 bucket.
