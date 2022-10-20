# API authentication

Funkwhale uses the OAuth [authorization grant flow](https://tools.ietf.org/html/rfc6749#section-4.1) for external apps. This flow is a secure way to authenticate apps that requires a user's explicit consent to perform actions.

```{mermaid}
%%{init: { 'sequence': {'mirrorActors': false} } }%%
  sequenceDiagram
    accTitle: "Funkwhale OAuth token flow"
    accDescr: "A sequence diagram showing how apps authenticate with Funkwhale"
    autonumber
    actor User
    participant A as Application
    participant F as Funkwhale web interface
    participant T as Token endpoint
    User ->> A: Log in to Funkwhale
    A ->> F: Direct to login screen
    F -->> User: Authenticate this app?
    User ->> F: Confirm
    F -->> A: Authorization code
    A ->> T: Authorization code and redirect URI
    T -->> A: Access token and refresh token
    loop Refresh
      A ->> T: Refresh token
      T -->> A: Access token
    end
```

```{contents} Steps
:local:
```

## 1. Create an application

To connect to the Funkwhale API using OAuth, you need to create an **application**. This represents the entity credentials are related to.

When creating an application you need to define the [**scopes**](https://www.rfc-editor.org/rfc/rfc6749#section-3.3) the application has access to. Scopes define what information your application can access. Each scope can be granted with the following rights:

- `read:<scope>`: grants read-only access to the resource
- `write:<scope>`: grants write-only access to the resource

`read` rights are required to fetch information using a `GET` request. All other actions (`POST`, `PATCH`, `PUT`, and `DELETE`) require `write` priviliges. You may give an application **both** `read` and `write` access to any scope.

```{list-table}
   :header-rows: 1

   * - Scope
     - Description
   * - `read`
     - Read-only access to all data
   * - `write`
     - Read-only access to all data
   * - `<read/write>:profile`
     - Access to profile data (email address, username, etc.)
   * - `<read/write>:libraries`
     - Access to library data (uploads, libraries, tracks, albums, artists, etc.)
   * - `<read/write>:favorites`
     - Access to favorites
   * - `<read/write>:listenings`
     - Access to history
   * - `<read/write>:follows`
     - Access to followers
   * - `<read/write>:playlists`
     - Access to playlists
   * - `<read/write>:radios`
     - Access to radios
   * - `<read/write>:filters`
     - Access to content filters
   * - `<read/write>:notifications`
     - Access to notifications
   * - `<read/write>:edits`
     - Access to metadata edits

```

Next, you need to define a [**Redirect URI**](https://www.rfc-editor.org/rfc/rfc6749#section-3.1.2). This is the location the user is redirected to once they authenticate your app. This can be any URI you want.

```{note}
Funkwhale supports the `urn:ietf:wg:oauth:2.0:oob` redirect URI for non-web applications. If you use this URI, the user is shown a token to copy and paste.
```

Once you've decided on your scopes and your redirect URI, you can create your app using one of the following methods:

1. Visit `/settings/applications/new` on your Funkwhale pod while logged in
2. Send a `POST` request to `/api/v1/oauth/apps`. See our [API documentation](https://docs.funkwhale.audio/swagger/) for more information

Both methods return a [**client ID**](https://www.rfc-editor.org/rfc/rfc6749#section-2.2) and a [**secret**](https://www.rfc-editor.org/rfc/rfc6749#section-2.3.1).

## 2. Get an authorization code

```{important}
Authorization codes are only valid for 5 minutes after the user approves the request.
```

You need an [**authorization code**](https://www.rfc-editor.org/rfc/rfc6749#section-1.3.1) to request an access token for your user. This code confirms to the server that a user has authorized access to their account.

To fetch an authorization code, you need to send the user to their Funkwhale pod to authenticate. This sends an [authorization request](https://www.rfc-editor.org/rfc/rfc6749#section-4.1.2) to the server.

To do this, call the `/authorize` endpoint with the following URL encoded query parameters:

- `client_id`* - Your application's client ID
- `response_type`* - Must be set to `code`.
- `redirect_uri` - Your redirect URI
- `scope` - A list of scopes
- `state` - Used to maintain state between the request and the callback to prevent cross-site request forgery. Typically corresponds with a location in the app (e.g. `/library`)

Here is an example URL: `https://demo.funkwhale.audio/authorize?response_type=code&scope=read%20write&redirect_uri=http%3A%2F%2Flocalhost%3A8080%2Fauth%2Fcallback&state=/library&client_id=jDOUfhqLlrbuOkToDCanZmBKEiyorMb9ZUgD2tFQ`.

When the user authorizes your app, the server responds with an authorization code. See [the OAuth spec](https://www.rfc-editor.org/rfc/rfc6749#section-4.1.2) for more information about this response.

## 3. Get an access token

Once you receive your authorization code, you need to [request an access token](https://www.rfc-editor.org/rfc/rfc6749#section-4.1.3). To request an access token, call the `/api/v1/oauth/token` endpoint with the following information:

- `grant_type`* - Must be set to `authorization_code`
- `code`* - Your application's authorization code
- `redirect_uri`* - Your redirect URI
- `client_id`* Your application's client ID

The server responds with an [`access_token`](https://www.rfc-editor.org/rfc/rfc6749#section-1.4) and a [`refresh_token`](https://www.rfc-editor.org/rfc/rfc6749#section-1.5). See [the OAuth spec](https://www.rfc-editor.org/rfc/rfc6749#section-4.1.4) for more information about this response.

You can use this token to authenticate calls from your application to the Funkwhale API by passing it as a request header with the following format: `Authorization: Bearer <token>`.

## 4. Refresh your access token

```{important}
When you refresh your token the endpoint returns a new `refresh_token`. You must update your refresh token each time you request a new access token.
```

By default, Funkwhale access tokens are valid for **10 hours**. Pod admins can configure this by setting the `ACCESS_TOKEN_EXPIRE_SECONDS` variable in their `.env` file.

After the access token expires, you must request a new access token by calling the `/api/v1/oauth/token` endpoint with the following information:

- `grant_type`* - Must be set to `refresh_token`
- `refresh_token`* - Your current refresh token
- `scope` - A list of scopes

See [the OAuth spec](https://www.rfc-editor.org/rfc/rfc6749#section-6) for more information about this response.
