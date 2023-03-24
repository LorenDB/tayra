# Use the Django dashboard

For some administration you need to access data that isn't available on the frontend. Funkwhale makes use of the [Django web framework](https://www.djangoproject.com/). This provides a dashboard that gives pod admins access to more tools and data than the frontend.

There are two ways to access the Django administration dashboard:

1. Navigate to `https://<yourdomain>/api/admin` and log in with your pod admin credentials.
2. Navigate to an object's moderation page and select {guilabel}`View in Django's admin` from the dropdown menu.

```{toctree}
---
caption: Administrative tasks
maxdepth: 1
---

delete-content

```
