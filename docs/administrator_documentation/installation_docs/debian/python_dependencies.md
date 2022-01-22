# 4. Install Python dependencies

The Funkwhale API is written in Python. You need to install the API's dependencies to run the software. We use [Poetry](https://python-poetry.org) to handle Python dependencies.

1. Install Poetry. Follow the steps in this wizard to set it up.

   ```{code} bash
   curl -sSL https://install.python-poetry.org | python3 -
   ```

2. Add Poetry to your `$PATH`. This allows you to use `poetry` commands.

   ```{code} bash
   export "$PATH=$HOME/.local/bin:$PATH" >> ~/.bashrc
   ```

3. Set up poetry in your `/srv/funkwhale/api` directory.

   ```{code} bash
   cd /srv/funkwhale/api
   poetry install
   ```

You're done! Poetry installs all Python dependencies.
