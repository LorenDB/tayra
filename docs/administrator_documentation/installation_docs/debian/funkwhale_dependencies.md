# 1. Install Funkwhale dependencies

To install Funkwhale on your server, you first need to install its dependencies. We provide all dependencies in a single file to enable you to install everything at once.

## Before you begin

Set a `FUNKWHALE_VERSION` variable to the version you want to install. You will use this version for all commands in this guide.

```{code} bash
export FUNKWHALE_VERSION=1.2.1
```

## Install Funkwhale dependencies

To install all Funkwhale dependencies, you need to download the dependencies file. You can pass the information from this file to `apt` using the following command:

```{code} bash
sudo apt install $(curl https://dev.funkwhale.audio/funkwhale/funkwhale/-/raw/$FUNKWHALE_VERSION/api/requirements.apt)
```

When prompted, hit {kbd}`y` to confirm the install.

That's it! `apt` installs all dependencies and tells you once it has finished.
