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

admin/index

```

```{toctree}
---
maxdepth: 1
caption: Moderator documentation
hidden: true
---

moderator_documentation/index
moderator_documentation/reports/index
moderator_documentation/domains/index
moderator_documentation/users/index
moderator_documentation/allow_listing/index

```

```{toctree}
---
maxdepth: 1
caption: Developer documentation
hidden: true
---

contributing
developers/index

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

````{panels}
:body: text-left
:header: text-center

{fa}`user` Users
^^^^^^^^^^^^

Looking to use Funkwhale for your content? Read through our guides to master the app!

+++

```{link-button} user_documentation/index
:type: ref
:text: Get started
:classes: btn-outline-primary btn-block stretched-link 
```

---

{fa}`wrench` Admins
^^^^^^^^^^^^^^^^

Want to host your own Funkwhale pod? Our admin documentation guides you through the process.

+++

```{link-button} admin/index
:type: ref
:text: Get started
:classes: btn-outline-primary btn-block stretched-link

---

{fa}`shield` Moderators
^^^^^^^^^^^^^^^^^^

Keeping your users safe from harassment and spam or clearing illegal content? Check out our moderator docs.

+++

```{link-button} moderator_documentation/index
:type: ref
:text: Get started
:classes: btn-outline-primary btn-block stretched-link

---

{fa}`code` Developers
^^^^^^^^^^^^^^^^^

Want to use Funkwhale's API or help with the project? Our developer docs give you what you need to get started.

+++

```{link-button} developers/index
:type: ref
:text: Get started
:classes: btn-outline-primary btn-block stretched-link

---
:column: col-lg-12 p-2

{fa}`users` Contributors
^^^^^^^^^^^^^^^^^^

Want to help make Funkwhale even better? Check out these guides for some ideas.

+++

```{link-button} contributing
:type: ref
:text: Get started
:classes: btn-outline-primary btn-block stretched-link

````
