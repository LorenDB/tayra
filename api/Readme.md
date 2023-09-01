# Funkwhale API

This is the Funkwhale API. Check out our [API explorer](https://docs.funkwhale.audio/swagger/) for interactive documentation.

## OAuth Authentication

Funkwhale uses the OAuth [authorization grant flow](https://tools.ietf.org/html/rfc6749#section-4.1) for external apps. This flow is a secure way to authenticate apps that requires a user's explicit consent to perform actions. You can use our demo server at <https://demo.funkwhale.audio> for testing purposes.

To authenticate with the Funkwhale API:

1. Create an application by sending a `POST` request to `api/v1/oauth/apps`. Include your scopes and redirect URI (use `urn:ietf:wg:oauth:2.0:oob`
   to get an authorization code you can copy)
2. Send an [authorization request](https://www.rfc-editor.org/rfc/rfc6749#section-4.1.2) to the `/authorize` endpoint to receive an authorization code
3. [Request an access token](https://www.rfc-editor.org/rfc/rfc6749#section-4.1.3) from `/api/v1/oauth/token`
4. Use your access token to authenticate your calls with the following format: `Authorization: Bearer <token>`
5. Refresh your access token by sending a refresh request to `/api/v1/oauth/token`

For more detailed instructions, see [our API authentication documentation](https://docs.funkwhale.audio/developers/authentication.html).

## Application token authentication

If you have an account on your target pod, you can create an application at `/settings/applications/new`. Once you authorize the application you can retrieve an access token. Use your access token to authenticate your calls with the following format: `Authorization: Bearer <token>`

## Rate limiting

Funkwhale supports rate-limiting as of version 0.2.0. Pod admins can choose to rate limit specific endpoints to prevent abuse and improve the stability of the service. If the server drops a request due to rate-limiting, it returns a `429` status code.

Each API call returns HTTP headers to pass the following information:

- What was the scope of the request (`X-RateLimit-Scope`)
- What is the rate-limit associated with the request scope (`X-RateLimit-Limit`)
- How many more requests in the scope can be made within the rate-limit timeframe (`X-RateLimit-Remaining`)
- How much time does the client need to wait to send another request (`Retry-After`)

For more information, check our [rate limit documentation](https://docs.funkwhale.audio/developer/api/rate-limit.html)

## Resources

For more information about API usage, refer to [our API documentation](https://docs.funkwhale.audio/api.html).
