# 9. Set up a reverse proxy

Funkwhale uses a reverse proxy to serve content to users. We use [Nginx](https://nginx.com) to serve this proxy. Follow this guide to install an Nginx configuration using details from your `.env` file.

1. Install Nginx.

   ```{code} bash
   sudo apt-get update
   sudo apt-get install nginx
   ```

2. Download the Nginx templates from Funkwhale. 

   ```{code} bash
   export FUNKWHALE_VERSION="1.2.1"
   sudo curl -L -o /etc/nginx/funkwhale_proxy.conf "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/$FUNKWHALE_VERSION/deploy/funkwhale_proxy.conf"
   sudo curl -L -o /etc/nginx/sites-available/funkwhale.template "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/$FUNKWHALE_VERSION/deploy/nginx.template"
   ```

3. Create an Nginx template with details from your `.env` file.

   ```{code} bash
   # Log in to a root shell.

   sudo su
   
   # Create an Nginx configuration using the Funkwhale template with details from your `.env` file.

   set -a && source /srv/funkwhale/config/.env && set +a
   envsubst "`env | awk -F = '{printf \" $%s\", $$1}'`" \
      < /etc/nginx/sites-available/funkwhale.template \
      > /etc/nginx/sites-available/funkwhale.conf

   # Enable the configuration so that Nginx serves it.

   ln -s /etc/nginx/sites-available/funkwhale.conf /etc/nginx/sites-enabled/

   # Exit the root shell.

   exit
   ```

That's it! You've created your Nginx file. Run the following command to check the `.env` details populated correctly.

```{code} bash
grep '${' /etc/nginx/sites-enabled/funkwhale.conf
```
