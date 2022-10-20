# Rate limiting

Funkwhale supports rate-limiting as of version 0.2.0. Pod admins can choose to rate limit specific endpoints to prevent abuse and improve the stability of the service. If the server drops a request due to rate-limiting, it returns a `429` status code.

By default, rate limits follow these rules:

1. Anonymous (unauthenticated) requests are subject to lower limits than authenticated requests
2. `PUT`, `DELETE`, `PUT`, `POST`, and `PATCH` requests are subject to lower limits than `GET` requests

You can return a full list of scope with their corresponding rate-limits by making a `GET` request to `/api/v1/rate-limit`.

## HTTP headers

Each API call returns HTTP headers to pass the following information:

- What was the scope of the request
- What is the rate-limit associated with the request scope
- How many more requests in the scope can be made within the rate-limit timeframe
- How much time does the client need to wait to send another request

Here is a full list of supported headers

```{list-table}
:header-rows: 1

   * - Header
      - Example value
      - Description
   * - `X-RateLimit-Limit`
      - 50
      - The number of requests allowed within a given period
   * - `X-RateLimit-Duration`
      - 3600
      - The time window, in seconds, during which the number of requests are measured
   * - `X-RateLimit-Scope`
      - `login`
      - The name of the scope computed for the request
   * - `X-RateLimit-Remaining`
      - 42
      - How many requests can be sent with the same scope before the rate-limit applies
   * - `Retry-After`
      - 3543
      - How many seconds the client must wait before it can retry. Only applies if `X-RateLimit-Remaining` is `0`
   * - `X-RateLimit-Reset`
      - 1568126089
      - A timestamp indicating when the `X-RateLimit-Remaining` value will reset
   * - `X-RateLimit-ResetSeconds`
      - 3599
      - The number of seconds until the `X-RateLimit-Remaining` value resets

```
