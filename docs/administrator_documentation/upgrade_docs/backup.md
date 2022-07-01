# Back up your Funkwhale instance

Before performing big changes, we recommend you back up your database and media files. Follow the instructions in this guide to back up your instance.

1. Back up your database.

   ````{tabbed} Debian

   ```{code} bash
   sudo -u postgres -H pg_dump funkwhale > /path/to/your/backup/dump_`date +%d-%m-%Y"_"%H_%M_%S`.sql
   ```

   ````

   ````{tabbed} Docker

   ```{code} bash
   docker-compose exec postgres pg_dumpall -c -U postgres > dump_`date +%d-%m-%Y"_"%H_%M_%S`.sql
   ```

   ````

2. Back up your media files. In this example we use [rsync](https://rsync.samba.org) to back up the files.

   ````{tabbed} Debian

   ```{code} bash
   rsync -avzhP /srv/funkwhale/data/media /path/to/your/backup/media
   rsync -avzhP /srv/funkwhale/data/music /path/to/your/backup/music
   ```

   ````

   ````{tabbed} Docker

   ```{code} bash

   rsync -avzhP /srv/funkwhale/data/media /path/to/your/backup/media
   rsync -avzhP /srv/funkwhale/data/music /path/to/your/backup/music
   ```

   ````

3. Back up your configuration files.

   ````{tabbed} Debian

   ```{code} bash
   rsync -avzhP /srv/funkwhale/config/.env /path/to/your/backup/.env
   ```

   ````

   ````{tabbed} Docker

   ```{code} bash
   rsync -avzhP /srv/funkwhale/.env /path/to/your/backup/.env
   ```

   ````

If you are performing regular backups, you may need deduplication and compression to keep the size down. In this case, a tool like [`borg`](https://www.borgbackup.org/) is more appropriate.
