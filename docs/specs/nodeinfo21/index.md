# NodeInfo 2.1

{bdg-secondary}`In progress`

## The issue

Servers need to communicate their capabilities in a network of communicating nodes to negotiate a common protocol.

## Proposed solution

Use [NodeInfo](http://nodeinfo.diaspora.software), a well-defined standard for exactly this purpose that's widely used within the Fediverse.

## Feature behavior

The NodeInfo endpoint is used to communicate the features and capabilities of a server. It presents details about:

- Implemented protocols
- Enabled features
- Usage statistics
- Content metadata

:::{seealso}
Read [the NodeInfo specification for more information](https://nodeinfo.diaspora.software/docson/index.html#/ns/schema/2.1#$$expand).
:::

The NodeInfo endpoint must contain all mandatory elements listed in the specification. In addition to this, Funkwhale's implementation should list additional details about the instance.

`actorId` (URL)
: The URL of the pod service actor

`private` (Boolean)
: Whether the pod is private

`shortDescription` (String)
: A short description of the pod

`longDescription` (String)
: A longer description of the pod

`rules` (String)
: A collection of rules users of the pod must abide by

`contactEmail` (Email address)
: The email address of the pod administrator

`terms` (String)
: The terms of use associated with the pod

`nodeName`(String)
: The name of the pod

`banner` (URL)
: The URL of the banner image

`defaultUploadQuota` (Number)
: The default upload quota (in megabytes) allowed for new users

`library.federationEnabled` (Boolean)
: Whether federation is enabled

`library.anonymousCanListen` (Boolean)
: Whether public endpoints require authentication

`supportedUploadExtensions` (Array\<String\>)
: A list of file extensions enabled for upload

`allowlist.enabled` (Boolean)
: Whether the pod admin has enabled allow-listing

`allowlist.domains` (Array\<String\>)
: A list of allowed domains

`funkwhaleSupportMessageEnabled` (Boolean)
: Whether the admin has enabled the Funkwhale project support message

`instanceSupportMessage` (String)
: The support message associated with the instance

`content.top_music_categories` (Array\<Object\>)
: The top three music genres and the number of uploads tagged with them

`content.top_podcast_categories` (Array\<Object\>)
: The top three podcast categories and the number of uploads tagged with them

`instance_policy.moderation_policy` (String)
: The moderation policy of the pod

`instance_policy.terms_of_service` (String)
: The terms of service of the pod

`instance_policy.languages` (Array\<String\>)
: The languages spoken by the pod administrators

`instance_policy.location` (String)
: The country the pod is located in

`federation.follows_instances` (Number)
: The number of Funkwhale pods that the target pod follows

`federation.following_instances` (Number)
: The number of Funkwhale pods that publicly follow the target pod

`features` (Array\<String\>)
: A list of enabled features

### Backend

A new NodeInfo endpoint will be created that sits alongside the existing `v1` endpoint for backwards-compatibility.

```text
/api/v2/instance/nodeinfo/2.1
```

This endpoint supports only `GET` requests and responds with the information outlined in the NodeInfo specification.

Example response:

```json
{
  "version": "2.1",
  "software": {
    "name": "Funkwhale",
    "version": "1.4.0",
    "repository": "https://dev.funkwhale.audio/funkwhale/funkwhale",
    "homepage": "https://funkwhale.audio"
  },
  "protocols": ["activitypub"],
  "services": {
    "inbound": ["atom1.0"],
    "outbound": ["atom1.0"]
  },
  "openRegistrations": true,
  "usage": {
    "users": {
      "total": 0,
      "activeHalfYear": 0,
      "activeMonth": 0
    },
    "localPosts": 0,
    "localComments": 0
  },
  "metadata": {
    "actorId": "string",
    "private": false,
    "shortDescription": "string",
    "longDescription": "string",
    "rules": "string",
    "contactEmail": "user@example.com",
    "terms": "string",
    "nodeName": "string",
    "banner": "string",
    "defaultUploadQuota": 0,
    "library": {
      "federationEnabled": true,
      "anonymousCanListen": true
    },
    "supportedUploadExtensions": ["string"],
    "allowList": {
      "enabled": true,
      "domains": ["string"]
    },
    "funkwhaleSupportMessageEnabled": true,
    "instanceSupportMessage": "string",
    "instance_policy": {
      "moderation_policy": "string",
      "terms_of_service": "string",
      "languages": ["string"],
      "location": "string"
    },
    "content": {
      "top_music_categories": [
        {
          "rock": 1256
        },
        {
          "jazz": 604
        },
        {
          "classical": 308
        }
      ],
      "top_podcast_categories": [
        {
          "comedy": 12
        },
        {
          "politics": 4
        },
        {
          "nature": 1
        }
      ],
      "federation": {
        "followed_instances": 0,
        "following_instances": 0
      }
    },
    "features": ["channels", "podcasts", "collections", "audiobooks"]
  }
}
```

## Availability

- [ ] Admin panel
- [ ] App frontend
- [ ] CLI
- [x] API

## Responsible parties

Since the actual endpoint is already standardized, Backend developers need only to agree on an implementation. The Frontend group needs to check to see if changing the location of `/.well-known/nodeinfo` has an impact on the web app.

The NodeInfo endpoint MUST be accompanied by a {download}`full OpenAPI schema file <schema.yml>` for ease of reference and implementation.

## Open questions

- [ ] Does changing `/.well-known/nodeinfo` have any implications on the Frontend?
