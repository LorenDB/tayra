# Install Funkwhale on your server

Choose your installation method and follow the guides to set up your pod.

Funkwhale requires the following:

- **A dedicated domain or subdomain** – you can't run Funkwhale in a subdirectory of a domain. You need to run it on a domain or a subdomain. For example: `https://mypod.io` or `https://funkwhale.mysite.io`.
- **Access to ports `80` and `443`** – Funkwhale uses these ports for federation.

```{toctree}
---
caption: Choose your installation method
maxdepth: 1
---

quick-install
docker
debian
third-party

```

```{toctree}
---
caption: Migrate your installation
maxdepth: 1
---

migrate

```
