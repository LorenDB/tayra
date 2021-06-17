Uninstall Funkwhale
===================

The following instructions helps you remove Funkwhale from your server, for instance after migrating to another server, or if you do not want to use Funkwhale anymore.

.. warning::

    The following instructions cannot be undone and might result in loss of data. If necessary, please make a backup of your server following the :doc:`backup instructions<backup>`.

    Especially, it must be noted that:

    - Remote content hosted on an S3 or S3-compatible server will not be removed.
    - In place imports will not be removed, provided they are located outside ``/srv/funkwhale/`` 

.. note::

    These instructions apply only for the manual installation on Debian or Arch Linux. It matches the default setup.

First, stop the all funkwhale related services:

.. code-block:: shell

    sudo systemctl stop funkwhale.target

Remove the reverse proxy configuration data and reload the reverse proxy.

If you are using nginx:

.. code-block:: shell

    sudo rm /etc/nginx/sites-enabled/funkwhale.conf    
    sudo rm /etc/nginx/sites-available/funkwhale.conf
    sudo rm /etc/nginx/funkwhale_proxy.conf

    sudo systemctl reload nginx

If you are using Apache2:

.. code-block:: shell

    sudo rm /etc/apache2/sites-enabled/funkwhale.conf    
    sudo rm /etc/apache2/sites-available/funkwhale.conf

    sudo service apache2 restart

Remove the systemd services:

.. code-block:: shell

    sudo systemctl disable funkwhale-server
    sudo systemctl disable funkwhale-worker
    sudo systemctl disable funkwhale-beat

    sudo rm /etc/systemd/system/funkwhale-server.service
    sudo rm /etc/systemd/system/funkwhale-worker.service
    sudo rm /etc/systemd/system/funkwhale-beat.service
    sudo rm /etc/systemd/system/funkwhale.target

    sudo systemctl daemon-reload
    sudo systemctl reset-failed

Then, remove the database:

.. code-block:: shell

    sudo -u postgres psql -c 'DROP DATABASE funkwhale;'
    sudo -u postgres psql -c 'DROP USER funkwhale;'

Finally, remove the user ``funkwhale`` and all funkwhale related data, including the server and the data:

.. code-block:: shell

    sudo userdel -r funkwhale

.. warning::

    The last command will remove ``/srv/funkwhale/``. On the default setup, this directory contains all user data. Please proceed cautiously!

    However, it must be noted that:

    - Remote content hosted on an S3 or S3-compatible server will not be removed.
    - In place imports will not be removed, provided they are not located in the directory ``/srv/funkwhale/``

.. note::

    If relevant, you might also want to:

    - remove the SSL certificates;
    - remove the corresponding DNS entries.