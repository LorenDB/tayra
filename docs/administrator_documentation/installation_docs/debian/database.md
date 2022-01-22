# 6. Set up your database

Funkwhale uses a [PostgreSQL](https://www.postgresql.org/) database to store information. Follow these steps to set up your database.

1. Install PostgreSQL and the `postgresql-contrib` package. This package contains extra features that Funkwhale uses.

   ```{code} bash
   sudo apt-get install postgresql postgresql-contrib
   ```

2. Once you've installed PostgreSQL, launch a `psql` shell as the `postgres` user to set up your database.

   ```{code} bash
   sudo -u postgres psql
   ```

3. Create your Funkwhale database.

   ```{code} psql
   CREATE DATABASE funkwhale WITH ENCODING 'utf8';
   ```

4. Create a user for Funkwhale. This user needs all privileges so it can manage the database.

   ```{code} psql
   CREATE USER funkwhale;
   GRANT ALL PRIVILEGES ON DATABASE funkwhale TO funkwhale;
   ```

5. Once you're finished, exit the shell

   ```{code} psql
   exit
   ```

6. Run the following commands to create extra extensions for the `funkwhale` database.

   ```{code} bash
   sudo -u postgres psql funkwhale -c 'CREATE EXTENSION "unaccent";'
   sudo -u postgres psql funkwhale -c 'CREATE EXTENSION "citext";'
   ```

7. Your database is ready to be populated! Use the `manage.py` script to create the database structure.

   ```{code} bash
   cd /srv/funkwhale/api
   poetry run python manage.py migrate
   ```

````{note}
You may see the following warning when applying migrations:

```{code}
"Your models have changes that are not yet reflected in a migration, and so won't be applied."
```

You can safely ignore this warning.
````

That's it! You've finished setting up your database.
