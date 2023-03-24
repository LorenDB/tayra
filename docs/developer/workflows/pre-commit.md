# Pre-commit

Funkwhale uses [pre-commit](https://pre-commit.com/) to ensure that the files you commit are properly formatted, follow best practice, and don't contain syntax or spelling errors.

You can install and setup pre-commit using the [quick-start guide on the pre-commit documentation](https://pre-commit.com/#quick-start). Make sure to install pre-commit and setup the git pre-commit hook so pre-commit runs before you commit any changes to the repository.

The workflow looks like this:

1. Install `pre-commit`.
2. After cloning the repository, setup the pre-commit git hooks:

   ```sh
   git clone git@dev.funkwhale.audio:funkwhale/funkwhale.git
   cd funkwhale

   pre-commit install
   ```

3. Make your changes and commit them.
4. If `pre-commit` fails to validate your changes, the commit process stops. Fix any reported errors and try again.
