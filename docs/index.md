# Welcome to Funkwhale's documentation

Funkwhale is a self-hosted audio player and publication platform. It enables users to build libraries of existing content and publish their own.

Funkwhale uses the [ActivityPub protocol](https://www.w3.org/TR/activitypub/) to talk to other apps across the {term}`Fediverse`. Users can share content between {term}`Funkwhale pods <Pod>` or with other Fediverse software.

```{toctree}
---
maxdepth: 1
hidden: true
caption: User documentation
---

user_documentation/index
user_documentation/accounts/index
user_documentation/channels/index
user_documentation/libraries/index
user_documentation/queue/index
user_documentation/playlists/index
user_documentation/radios/index
user_documentation/favorites/index
user_documentation/reports/index
user_documentation/subsonic/index
user_documentation/plugins/index
user_documentation/info/cli

```

```{toctree}
---
maxdepth: 1
caption: Admin documentation
hidden: true
---

administrator_documentation/index
administrator_documentation/installation_docs/index
administrator_documentation/configuration_docs/index
administrator_documentation/import_docs/index
administrator_documentation/upgrade_docs/index
administrator_documentation/migration_guide/index
administrator_documentation/django/index
administrator_documentation/manage_script/index
administrator_documentation/uninstall_docs/index
administrator_documentation/troubleshooting/index

```

```{toctree}
---
maxdepth: 1
caption: Moderator documentation
hidden: true
---

moderator_documentation/index
moderator_documentation/reports/index
moderator_documentation/internal_users/index
moderator_documentation/content/index
moderator_documentation/domains/index
moderator_documentation/external_users/index
moderator_documentation/allow_listing/index

```

```{toctree}
---
maxdepth: 1
caption: Developer documentation
hidden: true
---

developer_documentation/index
developer_documentation/setup/index
developer_documentation/contribute/index
developer_documentation/workflows/index
developer_documentation/api/index

```

```{toctree}
---
maxdepth: 1
caption: Contributor documentation
hidden: true
---

documentation/index
translators

```

```{toctree}
---
caption: Reference
maxdepth: 1
hidden: true
---

glossary

```

```{toctree}
---
caption: Changes
maxdepth: 1
hidden: true
---

changelog

```

::::{grid} 2

:::{grid-item-card}
:text-align: center

{fa}`user`  Users
^^^

Looking to use Funkwhale for your content? Read through our guides to master the app!

+++

```{button-link} user_documentation/index.html
:ref-type: myst
:color: primary
:outline:
:click-parent:
:expand:

Get started
```

:::
:::{grid-item-card}
:text-align: center

{fa}`wrench` Admins
^^^

Want to host your own Funkwhale pod? Our admin documentation guides you through the process.

+++

```{button-link} administrator_documentation/index.html
:ref-type: ref
:color: primary
:outline:
:click-parent:
:expand:

Get started
```

:::
:::{grid-item-card}
:text-align: center

{fa}`shield` Moderators
^^^

Keeping your users safe from harassment and spam or clearing illegal content? Check out our moderator docs.

+++

```{button-link} moderator_documentation/index.html
:ref-type: ref
:color: primary
:outline:
:click-parent:
:expand:

Get started
```

:::
:::{grid-item-card}
:text-align: center

{fa}`code` Developers
^^^

Want to use Funkwhale's API or help with the project? Our developer docs give you what you need to get started.

+++

```{button-link} developer_documentation/index.html
:ref-type: ref
:color: primary
:outline:
:click-parent:
:expand:

Get started
```

:::
::::

::::{grid} 1

:::{grid-item-card}
:text-align: center

{fa}`users` Contributors
^^^

Want to help make Funkwhale even better? Check out these guides for some ideas.

+++

```{button-link} contributing.html
:ref-type: ref
:color: primary
:outline:
:click-parent:
:expand:

Get started
```

:::
::::
