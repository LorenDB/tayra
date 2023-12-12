# Welcome to Funkwhale's documentation

Funkwhale is a self-hosted audio player and publication platform. It enables users to build libraries of existing content and publish their own.

Funkwhale uses the [ActivityPub protocol](https://www.w3.org/TR/activitypub/) to talk to other apps across the {term}`Fediverse`. Users can share content between {term}`Funkwhale pods <Pod>` or with other Fediverse software.

```{toctree}
---
maxdepth: 1
hidden: true
caption: User documentation
---

user/index
user/accounts/index
user/channels/index
user/libraries/index
user/queue/index
user/playlists/index
user/radios/index
user/favorites/index
user/reports/index
user/subsonic/index
user/plugins/index
user/info/cli

```

```{toctree}
---
maxdepth: 1
caption: Admin documentation
hidden: true
---

administrator/index
administrator/installation/index
administrator/configuration/index
administrator/import
administrator/upgrade/index
administrator/migration
administrator/django/index
administrator/manage-script/index
administrator/uninstall/index
administrator/troubleshooting/index

```

```{toctree}
---
maxdepth: 1
caption: Moderator documentation
hidden: true
---

moderator/index
moderator/reports/index
moderator/internal-users/index
moderator/content/index
moderator/domains/index
moderator/external-users/index
moderator/allow-listing/index

```

```{toctree}
---
maxdepth: 1
caption: Developer documentation
hidden: true
---

developer/index
developer/architecture
developer/setup/index
developer/contribute/index
developer/workflows/index
developer/api/index
developer/federation/index
developer/plugins/index

```

```{toctree}
---
maxdepth: 1
caption: Contributor documentation
hidden: true
---

contributor/index
contributor/documentation
contributor/translation

```

```{toctree}
---
maxdepth: 1
caption: Specifications
hidden: true
---

specs/collections/index
specs/nodeinfo21/index
specs/offline-mode/index
specs/quality-filter/index
specs/multi-artist/index
specs/user-follow/index

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
0.x Changelog <changes/funkwhale-0-changelog>

```

::::{grid} 2

:::{grid-item-card}
:text-align: center

{fa}`user` Users
^^^

Looking to use Funkwhale for your content? Read through our guides to master the app!

+++

```{button-link} user/index.html
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

```{button-link} administrator/index.html
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

```{button-link} moderator/index.html
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

```{button-link} developer/index.html
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

```{button-link} contributor/index.html
:ref-type: ref
:color: primary
:outline:
:click-parent:
:expand:

Get started
```

:::
::::
