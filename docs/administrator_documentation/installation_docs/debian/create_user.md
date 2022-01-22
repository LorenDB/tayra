# 2. Create a Funkwhale user

It's good practice to create a user on your server for Funkwhale administration. Doing this makes it easy to make sure you're running commands from the right place. Follow these steps to set up your user.

1. Create the `funkwhale` user and set its shell to `bash` and its home directory to `/srv/funkwhale`.

   ```{code} bash
   sudo useradd -r -s /usr/bin/bash -d /srv/funkwhale -m funkwhale
   ```

2. Create a password for the user. You need to do this so that you can use this user to perform database administration.

   ```{code} bash
   sudo passwd funkwhale
   ```

3. Finally, give the user `sudo` privileges. You need to do this so that the user can run administrative tasks.

   ```{code}
   usermod -aG sudo funkwhale
   ```

That's it! You've created your `funkwhale` user. Log in as this user when you want to perform any Funkwhale related tasks.
