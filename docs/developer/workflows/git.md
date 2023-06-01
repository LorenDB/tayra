# Git workflow

Funkwhale uses GitLab's merge requests to manage changes. The workflow looks like this:

1. Assign the issue you are working on to yourself, or create one if it doesn't exist
2. Create a fork of the project
3. Check out the `develop` branch. If you're making a minor change (such as fixing a typo) you can check out the `stable` branch
4. Create a new branch based on the checked out branch. Make sure to give your branch a meaningful name and include the issue number if required
5. Work on your changes locally. Try to keep each commit small to make reviews easier
6. Add a changelog fragment summarizing your changes
7. Lint the codebase using the following command:

   ::::{tab-set}

   :::{tab-item} API code

   ```sh
   black --check --diff . # Run the black linter in the project root to highlight any new issues
   ```

   :::

   :::{tab-item} Frontend code

   ```sh
   cd front
   yarn run eslint # Run eslint in the front directory
   ```

   :::

   ::::

8. Push your branch
9. Create a merge request in the GitLab frontend
10. We'll review your request and feed back

```{mermaid}
%%{init: { 'gitGraph': {'mainBranchName': 'stable'} } }%%
    gitGraph
        commit
        branch develop
        commit
        commit
        branch feature
        commit
        commit
        checkout develop
        merge feature
        commit
        checkout stable
        merge develop
```
