# 5. Set up your environment file

The environment file contains options you can use to control your Funkwhale pod. Follow these steps to get a working environment up and running.

1. Download the `.env` file to your `/srv/funkwhale/config` directory.

   ```{code} bash
   curl -L -o /srv/funkwhale/config/.env "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/$FUNKWHALE_VERSION/deploy/env.prod.sample"
   ```

2. Generate a secret key for Django. This keeps your Funkwhale data secure. Do not share this key with anybody.

   ```{code} bash
   openssl rand -base64 45
   ```

3. Reduce the permissions on your `.env` file to `600`. This means that only the `funkwhale` user can read and write this file.

   ```{code} bash
   chmod 600 /srv/funkwhale/config/.env
   ```

4. Open the `.env` file in a text editor. For this example, we will use `nano`.

   ```{code} bash
   nano /srv/funkwhale/config/.env
   ```

5. Update the following settings:
   - Paste the seccret key in the `DJANGO_SECRET_KEY` field.
   - Populate the `DATABASE_URL` field:

      ```{code}
      DATABASE_URL=postgresql://funkwhale@:5432/funkwhale
      ```

   - Populate the `CACHE_URL` field:

      ```{code}
      CACHE_URL=redis://127.0.0.1:6379/0
      ```

   - Populate the `FUNKWHALE_HOSTNAME` field with the URL of your server.

6. Hit {kbd}`ctrl + x` then {kbd}`y` to save the file and close `nano`.

You're done! Your environment file is now ready to go. You can check out a full list of configuration options in our Environment file guide.
