# Change your instance URL

```{danger}
We recommend you don't change your instance URL. Changing it __will__ cause instability and problems. If you change your URL, the Funkwhale project can't offer support for problems that arise.
```

Your instance URL is your pod's unique identifier. If you want to change it, you need to update a lot of information

- The instance URL in your {file}`.env` file.
- The instance URL in your webserver config.
- Any references to the old URL in your database.

## Update your instance URL

1. Change the `FUNKWHALE_HOSTNAME` and `DJANGO_ALLOWED_HOSTS` value in your {file}`.env` file.
2. Change the `server_name` values in your {file}`/etc/nginx/sites-enabled/funkwhale.conf` file.
3. Restart your webserver to pick up the changes.

   ::::{tab-set}

   :::{tab-item} Nginx
   :sync: nginx

   ```{code-block} sh
   sudo systemctl restart nginx
   ```

   :::

   :::{tab-item} Apache
   :sync: apache

   ```{code-block} sh
   sudo systemctl restart apache2
   ```

   :::
   ::::
