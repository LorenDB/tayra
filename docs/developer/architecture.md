# Project architecture

Funkwhale is made up of several components. Understanding these components and what they do is important when contributing to Funkwhale's codebase. In this article, we'll break down each part of Funkwhale's architecture to help you understand what each component does.

Below is a diagram of Funkwhale's project setup.

```{mermaid}
   flowchart TD
      accTitle: Funkwhale data flow diagram
      accDescr: A diagram showing the components of the Funkwhale app and how data flows through each component.
      subgraph Entrypoints
      user[User] --> frontend[Funkwhale web app]
      user --> ffa[Funkwhale for Android]
      user --> subsonic[Subsonic app]
      frontend --> proxy[Nginx/Apache reverse proxy]
      ffa --> proxy
      subsonic --> proxy
      end
      subgraph Funkwhale backend
      proxy --> api[Django API server]
      api --> db[PostgreSQL database]
      api --> redis[Redis cache and message queue]
      beat[Celery beat task scheduler] --> redis
      redis <--> celery[Celery worker]
      celery --> db
      end
```

Select a link below to see information about each component.

```{contents}
:local:
```

## Entrypoints

Users can access Funkwhale using a variety of entrypoints. They can make use of a Funkwhale application, a Subsonic-compatible application, or by calling the API directly. Each entrypoint interacts with the Funkwhale backend in the same way.

### Funkwhale web app

The Funkwhale web app is a {abbr}`SPA (Single Page Application)` written in [Vue.js](https://vuejs.org) and [Typescript](https://typescriptlang.org). This is the application most people associate with Funkwhale. Server admins usually run an instance of the web app alongside their Funkwhale {term}`pod`, but you can also connect a standalone web app to another pod.

The Funkwhale web app interacts with the Funkwhale API to fetch and update data. Using a service worker, the web app caches important information for offline use.

### Funkwhale for Android

Funkwhale for Android is the Funkwhale collective's official Android app written in [Kotlin](https://kotlinlang.org/). It interacts with the Funkwhale API to fetch and update data and stores information for offline playback.

### Subsonic app

Funkwhale supports a limited subset of the [Subsonic API](http://www.subsonic.org/pages/api.jsp) to support existing Subsonic apps. These apps can request data stored on a Funkwhale server by calling these endpoints.

### Nginx/Apache reverse proxy

The reverse proxy acts as a layer between a Funkwhale pod and the open internet. It enhances the pod's security and provides additional options to help increase performance.

When a user tries to communicate with a Funkwhale pod, the reverse proxy:

1. Handles the HTTP/HTTPS requests and proxies them to the Funkwhale API server
2. Serves requested static files, such as audio files and stylesheets

## Backend

The Funkwhale backend is made up of a few components which are responsible for:

1. Communicating with the user's entrypoint and actioning requests
2. Maintaining data consistency
3. Communicating with other Funkwhale pods (if federation is enabled)

### Django API server

The Funkwhale API is a [REST API](https://developer.mozilla.org/en-US/docs/Glossary/REST) written in [Python](https://www.python.org/) using the [Django REST framework](https://www.django-rest-framework.org/). It is the central piece of the project and houses the application's logic.

The Funkwhale API is responsible for:

1. Fetching requested data from the cache/database and returning it to the requester in a meaningful way
2. Processing incoming data and writing it to the database in a meaningful way
3. Delegating long-running tasks to workers to reduce load

### PostgreSQL database

Funkwhale uses a [PostgreSQL database](https://www.postgresql.org/) to store data. All information that is served by and sent to the Funkwhale API is stored in this database.

The Funkwhale database makes heavy use of [indexes](https://www.postgresql.org/docs/current/indexes.html) for enhanced performance.

### Redis cache and message queue

Funkwhale uses [Redis](https://redis.io/) to cache information from the database and to store a queue of messages to send. We use this cache to avoid locking database resources and to speed up requests.

### Celery worker

Funkwhale has to handle a lot of tasks that take longer than the average HTTP request/response cycle. To ensure these tasks complete and don't impact the API's performance, they are offloaded to a [Celery](https://docs.celeryq.dev/en/stable/userguide/workers.html) task worker. The worker then works through all the tasks in its queue while the API handles real-time responses.

Some common tasks the Celery worker handles are:

- Importing uploaded music to the database
- Handling [ActivityPub](https://www.w3.org/TR/activitypub/) messages from other {term}`Fediverse` servers
- Scanning new content on remote pods

### Celery beat task scheduler

In addition to handling tasks from the API, the Celery worker also needs to handle some recurring tasks. To manage these, we implement a [Celery beat](https://docs.celeryq.dev/en/stable/reference/celery.apps.beat.html#celery.apps.beat.Beat) scheduler. The scheduler is responsible for triggering tasks on a schedule and adding messages to the [queue](#redis-cache-and-message-queue) so the worker can work through them.

Some common recurring tasks are:

- Clearing the cache
- Refreshing content metadata
