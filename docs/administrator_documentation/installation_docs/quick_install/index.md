# Install Funkwhale with the quick install script

The quick install script is the easiest way to install Funkwhale. Run this script on a [Debian](https://debian.org)-based server to get your pod set up.

## Before you begin

- You need `sudo` access to run the quick install script.
- The quick install script installs Nginx, PostgreSQL, and Redis by default. You can customize this behavior by selecting the options in the script.

## 1. Install dependencies

To download the quick install script, install `curl`:

```{code} bash
sudo apt update # update the apt cache
sudo apt install curl
```

## 2. Install Funkwhale

Now that you have `curl` installed, download and run the quick install script:

```{code} bash
sudo sh -c "$(curl -sSL https://get.funkwhale.audio/)"
```

The script will prompt you to enter information about your instance. Follow the onscreen prompts until the script completes.

That's it! You've finished installing Funkwhale. You should now be able to visit your pod in your web browser.
