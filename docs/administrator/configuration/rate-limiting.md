# Rate limit API endpoints

This article contains a summary of the endpoints you can control using rate-limiting. You can change the rate limits for these endpoints using the [`THROTTLING_RATES`](env-file.md#api-configuration) environment variable.

## Standard endpoints

```{list-table}
:header-rows: 1

* - Endpoint name
   - Description
   - Default rate (per user)
* - `anonymous-wildcard`
   - Anonymous requests not covered by other limits
   - 1000 per hour
* - `authenticated-wildcard`
   - Authenticated requests not covered by other limits
   - 2000 per hour
* - `authenticated-create`
   - Authenticated POST requests
   - 1000 per hour
* - `anonymous-create`
   - Anonymous POST requests
   - 1000 per day
* - `authenticated-list`
   - Authenticated GET requests
   - 10000 per hour
* - `anonymous-list`
   - Anonymous GET requests
   - 10000 per day
* - `authenticated-retrieve`
   - Authenticated GET requests on resource details
   - 10000 per hour
* - `anonymous-retrieve`
   - Anonymous GET requests on resource details
   - 10000 per day
* - `authenticated-destroy`
   - Authenticated DELETE requests on resource details
   - 500 per hour
* - `anonymous-destroy`
   - Anonymous DELETE requests on resource details
   - 1000 per day
* - `authenticated-update`
   - Authenticated PATCH and PUT requests on resource details
   - 1000 per hour
* - `anonymous-update`
   - Anonymous PATCH and PUT requests on resource details
   - 1000 per day
* - `subsonic`
   - All Subsonic API requests
   - 2000 per hour

```

## User action endpoints

```{list-table}
:header-rows: 1

* - Endpoint name
   - Description
   - Default rate (per user)
* - `login`
   - User login
   - 30 per hour
* - `signup`
   - User signup
   - 10 per day
* - `verify-email`
   - Email address confirmation
   - 20 per hour
* - `password-change`
   - Password change (when authenticated)
   - 20 per hour
* - `password-reset`
   - Password reset request
   - 20 per hour
* - `password-reset-confirm`
   - Password reset confirmation
   - 20 per hour
* - `fetch`
   - Fetch remote objects
   - 200 per day

```

## Dangerous endpoints

```{list-table}
:header-rows: 1

* - Endpoint name
   - Description
   - Default rate (per user)
* - `authenticated-reports`
   - Authenticated report submissions
   - 100 per day
* - `anonymous-reports`
   - Anonymous report submissions
   - 10 per day
* - `authenticated-oauth-app`
   - Authenticated OAuth app creation
   - 10 per hour
* - `anonymous-oauth-app`
   - Anonymous OAuth app creation
   - 10 per day
* - `oauth-authorize`
   - OAuth app authorization
   - 100 per hour
* - `oauth-token`
   - OAuth token creation
   - 100 per hour
* - `oauth-revoke-token`
   - OAuth token deletion
   - 100 per hour

```
