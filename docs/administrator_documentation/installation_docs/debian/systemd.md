# 8. Set up systemd unit files

Funkwhale uses [systemd](https://www.freedesktop.org/wiki/Software/systemd/) to manage its services. systemd helps prevent downtime by bringing services back up if they fail. It also starts your Funkwhale services after a reboot. Follow these steps to set up Funkwhale services with systemd.

1. Download the sample unit files from Funkwhale.

   ```{code} bash
   sudo curl -L -o "/etc/systemd/system/funkwhale.target" "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/$FUNKWHALE_VERSION/deploy/funkwhale.target"
   sudo curl -L -o "/etc/systemd/system/funkwhale-server.service" "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/$FUNKWHALE_VERSION/deploy/funkwhale-server.service"
   sudo curl -L -o "/etc/systemd/system/funkwhale-worker.service" "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/$FUNKWHALE_VERSION/deploy/funkwhale-worker.service"
   sudo curl -L -o "/etc/systemd/system/funkwhale-beat.service" "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/$FUNKWHALE_VERSION/deploy/funkwhale-beat.service"
   ```

2. Reload systemd to register the new services.

   ```{code} bash
   sudo systemctl daemon-reload
   ```

3. Start all Funkwhale services.

   ```{code} bash
   sudo systemctl start funkwhale.target
   ```

4. Enable the services. Systemd can then start the services after a reboot.

   ```{code} bash
   sudo systemctl enable funkwhale-server
   sudo systemctl enable funkwhale-worker
   sudo systemctl enable funkwhale-beat
   ```

That's it! systemd keeps these services running and starts them up in the correct order after a reboot.
