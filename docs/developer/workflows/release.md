# Make a release

Once we're ready to release a new version of the software, we can use the following process:

1. Export the new release version

   ```sh
   export NEXT_RELEASE=1.3.0
   ```

2. Export the previous release version

   ```sh
   export PREVIOUS_RELEASE=1.2.9
   ```

3. Pull the latest version of the `develop` branch. Use `stable` if you're releasing a bugfix.

   ::::{tab-set}

   :::{tab-item} Bugfix release
   :sync: bugfix

   ```sh
   git checkout stable
   git pull
   ```

   :::

   :::{tab-item} Feature release
   :sync: feature

   ```sh
   git checkout develop
   git pull
   ```

   :::

   ::::

4. Compile the changelog

   ```sh
   towncrier build --version $NEXT_RELEASE
   ```

5. Check the output and fix typos and mistakes
6. Add a list of contributors

   ```sh
   python3 scripts/get-contributions-stats.py $NEXT_RELEASE # Output a list of contributors
   git log $PREVIOUS_RELEASE.. --format="- %aN" --reverse | sort | uniq # Get a list of all commit authors
   nano CHANGELOG # Add these lists to the CHANGELOG
   ```

7. Update the `__version__` variable to the next release version

   ```sh
   nano api/funkwhale_api/__init__.py
   ```

8. Commit all changes

   ```sh
   git add .
   git commit -m "Version bump and changelog for $NEXT_RELEASE"
   ```

9. Create a tag

   ```sh
   git tag $NEXT_RELEASE
   ```

10. Publish the new tag to GitLab

    ```sh
    git push --tags && git push
    ```

11. Merge your changes into the alternate branch

    ::::{tab-set}

    :::{tab-item} Bugfix release
    :sync: bugfix

    ```sh
    git checkout develop && git merge stable && git push
    ```

    :::

    :::{tab-item} Feature release
    :sync: feature

    ```sh
    git checkout stable && git merge develop && git push
    ```

    :::

    ::::

Don't forget to create a blog post to announce the new release!
