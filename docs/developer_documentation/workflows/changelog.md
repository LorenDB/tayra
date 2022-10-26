# Changelog fragments

We try to add changelog fragments when we make changes so that we can show users what we've done. These fragments are small text files that contain a summary of changes. When we make a release, we compile these into a full changelog using [towncrier](https://pypi.org/project/towncrier/).

Each changelog fragment should contain a short and meaningful summary of changes and include the issue number (where applicable). For example:

```text
Fixed broken audio player on Chrome 42 for ogg files (#567)
```

If there's no issue, insert the merge request identifier instead:

```text
Fixed a typo in landing page copy (!342)
```

## Naming

Changelog fragments use the following naming convention: `changes/changelog.d/<name>.category>`. The `<name>` can be anything that describes your work, or the issue ID. The category can be one of the following:

- `feature` – a new feature
- `enhancement` – an extension of an existing feature
- `bugfix` – a bugfix or patch
- `refactoring` – refactored code
- `doc` – new documentation
- `i18n` – internationalization-related work
- `misc` – any work that doesn't fit into the above categories

You can create these files manually or use the following command to create a fragment:

```sh
towncrier new --edit $issue.$category
```
