# User following

## Terminology

The following terminology is used throughout this document:

User
: A **person** with an account on a Funkwhale server or ActivityPub-enabled platform.

Follow
: The act of subscribing to a user's activities to render them in a feed as they occur.

Object
: A collection of information - formatted as [`JSON-LD`](https://json-ld.org/) - that represents entities such as content, users, or activities performed in Funkwhale. See the [ActivityPub specification](https://www.w3.org/TR/activitypub/#obj) for more details.

Activity
: A verb that describes an action targeting an **Object**. This informs the receiving server what it needs to do with the object. For example: `Create`, `Delete`, `Undo`, `Follow`, `Block`.

Actor
: An ActivityPub object representing an entity capbable of performing actions. See the [ActivityPub specification][actor] for more details.

Requesting user
: The user who sends a request. For example: If **Bob** requests to follow **Alice**, **Bob** is the requesting user.

Target user
: The user who is the subject of a request. For example: If **Bob** requests to follow **Alice**, **Alice** is the target user.

## The issue

Funkwhale is an audio platform with an emphasis on social interaction across a federated network of servers. To this end, Funkwhale users should be able to interact with one another in meaningful ways.

Funkwhale users broadcast the following activity when using the software:

1. **Favoriting** content
2. **Listening** to content

Users across the federated web should be able to follow Funkwhale accounts to receive this activity in their streams.

## Proposed solution

To facilitate this, Funkwhale uses the following mechanisms:

- The **Funkwhale client API** for user to user interactions on the same server
- [ActivityPub](https://www.w3.org/TR/activitypub) for server-to-server (S2S) interactions between users

Users should be able to discover other users using the [Webfinger protocol][webfinger] and render their public details in a manner compliant with the platform they use. Within Funkwhale, user activity should be rendered natively. Other Fediverse software may choose how to render this information.

This specification outlines the workflows for the following actions for **local** and **remote** requests:

1. User discovery
2. User follows
3. User unfollows
4. User blocking

### User discovery

Funkwhale implements the [Webfinger protocol][webfinger] for account discovery. When the **requesting user** enters the **target user's** federation handle, Funkwhale should attempt to resolve the location of the **target user** by querying the `acct:` resource with the URL encoded handle.

#### Webfinger request

```console
$ curl -X GET \
-H "Content-type: application/json" \
'https://open.audio/.well-known/webfinger?resource=acct:user%40open.audio'
```

#### Response

```json
{
  "subject": "acct:user@open.audio",
  "links": [
    {
      "rel": "self",
      "href": "https://open.audio/federation/actors/user",
      "type": "application/activity+json"
    }
  ],
  "aliases": ["https://open.audio/federation/actors/user"]
}
```

#### Web app behavior

When a requesting user enters the handle of a target user in the search bar, Funkwhale does the following:

1. Verifies the handle is well-formed
2. Forwards the request to the server

The server is responsible for dereferencing the Webfinger query. The server does the following:

1. Queries the domain for the account using Webfinger
   - **If** the domain doesn't have a Webfinger endpoint, returns a meaningful error message. This must be displayed to the user.
   - **If** the server is subject to a domain filter, or is filtering the requesting server, returns a meaningful error message. This must be displayed to the user.
   - **If** no user is found on the domain, returns a meaningful error message.
2. If a matching user is found, the server should return the URL of the resource to the web app. The web app should then redirect the requesting user to a user page that shows the target user's profile image and preferred username
   - **If** the target user has set their activity to **public**, the web app should render their **Favorites** and **Recently Listened** activity

```{mermaid}
flowchart TD
    search([A requesting user enters a fediverse handle\nin the search bar]) --> query(Funkwhale queries the target domain)
    query --> webfinger{Does the target server\support Webfinger?}
    subgraph Request verification
        webfinger -->|no| error([The server returns an error message])
        webfinger -->|yes| filter{Is the requesting server subject\nto a domain filter or vice versa?}
        filter -->|yes| error
        filter -->|no| userfound{Was the target user found\non the server?}
        userfound -->|no| error
    end
    userfound -->|yes| redirect([The user is redirected to a profile page\nin the web app])
```

### Following users

Following a user is a process by which a **requesting user** subscribes to the activities of a **target user**. If the **target user** accepts the follow request, the **requesting user** receives any new activities in their home feed.

#### API behavior

Follow requests should be handled by an endpoint using a `POST` request. This request must immediately return a status message to the client.

```text
POST /api/v2/users/{id}/follow
```

When the server receives a `follow` request, it creates a `follow_request` object containing the status of the follow request which is used to display request information to the target user in their notifications.

:::{note}
If the **target user** has configured their profile to be _public_, all `Follows` are `Accepted` immediately.
:::

#### ActivityPub behavior

If the **target user** is on a different server to the **requesting user**, the request is handled using the [ActivityPub `Follow` activity][follow]:

1. A [`Follow` activity][follow] is posted to the **requesting user's** [outbox collection][outbox] with the **target user** as the recipient
2. The **target user** receives the request in their [inbox collection][inbox]
3. The **target user** then needs to [`Accept`][accept] or [`Reject`][reject] the [`Follow`][follow]
   - If the **target user** accepts the follow, the **requesting user** is added to the **target user's** [following collection][following]. The **target user** is added to the **requesting user's** [followers collection][followers]
   - If the **target user** rejects the follow, the **requesting user** is _not_ added to the **target user's** [following collection][following]. The **target user** is _not_ added to the **requesting user's** [followers collection][followers]

```{mermaid}
sequenceDiagram
    autonumber
    Bob ->> Bob's Outbox : Follow request
    note over Bob's Outbox, Bob's Inbox : Bob's ActivityPub collections
    Bob's Outbox ->> Alice's Inbox : Follow request
    note over Alice's Inbox, Alice's Outbox : Alice's ActivityPub collections
    Alice's Inbox ->> Alice : Display follow request
    activate Alice
    alt if Alice accepts Bob's request
        Alice -->> Alice's Outbox : Accept follow
        Alice's Outbox --> Bob's Inbox : Accept
        Bob's Inbox --> Bob : Display following
    end
    alt if Alice rejects Bob's request
        Alice -->> Alice's Inbox : Reject follow
    end
```

:::{note}
If the **target user** has configured their activity to be _public_, all `Follows` are `Accepted` immediately.
:::

#### Web app behavior

In the Funkwhale web app, the **requesting user** sees a **Follow** button on the **target user's** profile page. When they select this button, the following happens:

1. If the **target user's** profile can be followed, an action button is displayed.
2. When the **requesting user** attempts the follow the **target user**, the button should change to a {guilabel}`Pending` status.
3. If the **target user** `Accepts` the follow request, the button should update to show a {guilabel}`Following` status.

### Unfollowing users

Following a user is a process by which a **requesting user** unsubscribes from the activities of a **target user**. A **requesting user** may unfollow a **target user** unilaterally at any time to stop receiving updates.

#### API behavior

Follow requests should be handled by an endpoint using a `POST` request. This request must immediately return a status message to the client.

```text
POST /api/v2/users/{id}/unfollow
```

#### ActivityPub behavior

If the **target user** is on a different server to the **requesting user**, the request is handled using the [ActivityPub `Undo` activity][undo]:

1. An [`Undo` activity][undo] is posted to the **requesting user's** [outbox collection][outbox] with a [`Follow activity`][follow] as the target
2. The **target user** is removed from the **requesting user's** [following collection][following]
3. The **target user** receives the undo request in their [inbox collection][inbox]
4. The **requesting user** is removed from the **target user's** [followers collection][followers]

```{mermaid}
sequenceDiagram
    autonumber
    Bob ->> Bob's Outbox : Undo request
    note over Bob, Bob's Outbox : The target user is removed
    Bob's Outbox ->> Alice's Inbox : Undo Follow
    note over Alice's Inbox, Alice : The requesting user is removed
```

#### Web app behavior

When a **requesting user** unfollows a **target user**, the UI must update to visually indicate that the action has succeeded. All activities relating to the **target user** must be visually hidden.

### Blocking users

When one user blocks another, no information may be shared between them. Blocking is a unilateral action that can be taken by both **requesting** and **target** actors to prevent the other from interacting with them.

#### API behavior

Block requests should be handled by an endpoint using a `POST` request. This request must immediately return a status message to the client.

```text
POST /api/v2/users/{id}/block
```

#### ActivityPub behavior

If the the **blocked user** is on a different server to the **blocking user**, the request is handled using the [ActivityPub `Block` activity][block] with the **blocked user's** [`Actor`][actor] as a target.

1. A [`Block` activity][block] is posted to the **blocking user's** [outbox collection][outbox] with the **blocked user's** [`Actor`][actor] the target
   - If the **blocked user** was previously in the **blocking user's** [following collection][following], they are removed
   - If the **blocked user** was previously in the **blocking user's** [followers collection][followers], they are removed

:::{warning}
As noted in the ActivityPub spec, the **blocked user** must _not_ be informed of the `Block` activity.
:::

#### Web app behavior

When a **blocking user** blocks a **blocked user**, the UI must update to visually indicate that the action has succeeded. All activities relating to the **blocked user** must be visually hidden.

If a **blocking user** navigates to the profile of a **blocked user** who has blocked them, the UI _must not_ reflect that they are blocked. The **blocking user** must be able to send a follow request which is _not_ sent to the **blocked user**.

### Unblocking users

**Blocking users** can unilaterally reverse blocks they have imposed on **blocked users**. This enables them to request to follow the **blocked user's** activities again.

#### API behavior

Unblock requests should be handled by an endpoint using a `POST` request. This request must immediately return a status message to the client.

```text
POST /api/v2/users/{id}/unblock
```

#### ActivityPub behavior

If the **blocked user** is on a different server to the **blocking user**, the request is handled using the [ActivityPub `Undo` activity][undo].

#### Web app behavior

When a **blocking user** unblocks a **blocked user**, the UI must update to visually indicate that the action has succeeded. The **Follow** button must become active and interactive again.

## Availability

- [x] App frontend
- [x] CLI

## Responsible parties

The following working groups are responsible for implementing this feature:

- The **Backend group** is responsible for building the API endpoints and ActivityPub S2S logic
- The **Design group** is responsible for drafting designs for the web app interactions
- The **Frontend group** is responsible for implementing the desigs from the **Design group** and adding support for the new API
- The **Documentation group** is responsible for finalizing the specification of the feature and documenting it for users

## Open questions

- The API actions and endpoint names are placeholders. We need to decide what they should be called
- What limitations are there when fetching activities from remote actors?
- How should a user's followers collection, following collection, and pending requests be displayed in the web app?
- How are followed activities fetched and displayed to a user?

## Minimum viable product

The MVP for this feature is to implement the backend logic to enable Funkwhale users to follow one another. This can be added to the web app using existing profile fetching logic.

### Next steps

Once the backend logic is implemented, the frontend implementation should be revisited to improve the UX and discoverability. Additional features such as showing federated favorites on audio objects should also be considered.

[webfinger]: https://www.rfc-editor.org/rfc/rfc7033
[outbox]: https://www.w3.org/TR/activitypub/#outbox
[inbox]: https://www.w3.org/TR/activitypub/#inbox
[accept]: https://www.w3.org/TR/activitypub/#accept-activity-inbox
[reject]: https://www.w3.org/TR/activitypub/#reject-activity-inbox
[follow]: https://www.w3.org/TR/activitypub/#follow-activity-outbox
[actor]: https://www.w3.org/TR/activitypub/#actors
[following]: https://www.w3.org/TR/activitypub/#following
[followers]: https://www.w3.org/TR/activitypub/#followers
[undo]: https://www.w3.org/TR/activitypub/#undo-activity-outbox
[block]: https://www.w3.org/TR/activitypub/#block-activity-outbox
