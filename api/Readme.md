Interactive documentation for [Funkwhale](https://funkwhale.audio) API.

Backward compatibility between minor versions (1.X to 1.Y) is guaranteed for all the
endpoints documented here.

Usage
-----

Click on an endpoint name to inspect its properties, parameters and responses.

Use the "Try it out" button to send a real world payload to the endpoint and inspect
the corresponding response.

OAuth Authentication
--------------------

You can register your own OAuth app using the `/api/v1/oauth/apps/` endpoint. Proceed to the standard OAuth flow afterwards:

- Our authorize URL is at `/authorize`
- Our token acquisition and refresh URL is at `/api/v1/oauth/token`
- The list of supported scopes is available by clicking the `Authorize` button in the Swagger UI documentation
- Use `urn:ietf:wg:oauth:2.0:oob` as your redirect URI if you want the user to get a copy-pastable authorization code
- At the moment, endpoints that deal with admin or moderator-level content are not accessible via OAuth, only through the Web UI

You can use our demo server at `https://demo.funkwhale.audio` for testing purposes.

Application token authentication
--------------------------------

If using OAuth isn't practical and you have an account on the Funkwhale pod, you can create an application by visiting `/settings`.

Once the application is created, you can authenticate using its access token in the `Authorization` header, like this: `Authorization: Bearer <token>`. 

Rate limiting
-------------

Depending on server configuration, pods running Funkwhale 0.20 and higher may rate-limit incoming
requests to prevent abuse and improve the stability of service. Requests that are dropped because of rate-limiting
receive a 429 HTTP response.

The limits themselves vary depending on:

- The client: anonymous requests are subject to lower limits than authenticated requests
- The operation being performed: Write and delete operations, as performed with DELETE, POST, PUT and PATCH HTTP methods are subject to lower limits

Those conditions are used to determine the scope of the request, which in turns determine the limit that is applied.
For instance, authenticated POST requests are bound to the `authenticated-create` scope, with a default limit of
1000 requests/hour, but anonymous POST requests are bound to the `anonymous-create` scope, with a lower limit of 1000 requests/day.

A full list of scopes with their corresponding description, and the current usage data for the client performing the request
is available via the `/api/v1/rate-limit` endpoint.

Additionally, we include HTTP headers on all API response to ensure API clients can understand:

- what scope was bound to a given request
- what is the corresponding limit
- how much similar requests can be sent before being limited
- and how much time they should wait if they have been limited

<table>
<caption>Rate limiting headers</caption>
<thead>
<th>Header</th>
<th>Example value</th>
<th>Description value</th>
</thead>
<tbody>
<tr>
<td><code>X-RateLimit-Limit</code></td>
<td>50</td>
<td>The number of allowed requests whithin a given period</td>
</tr>
<tr>
<td><code>X-RateLimit-Duration</code></td>
<td>3600</td>
<td>The time window, in seconds, during which those requests are accounted for.</td>
</tr>
<tr>
<td><code>X-RateLimit-Scope</code></td>
<td>login</td>
<td>The name of the scope as computed for the request</td>
</tr>
<tr>
<td><code>X-RateLimit-Remaining</code></td>
<td>42</td>
<td>How many requests can be sent with the same scope before the limit applies</td>
</tr>
<tr>
<td><code>Retry-After</code> (if <code>X-RateLimit-Remaining</code> is 0)</td>
<td>3543</td>
<td>How many seconds to wait before a retry</td>
</tr>
<tr>
<td><code>X-RateLimit-Reset</code></td>
<td>1568126089</td>
<td>A timestamp indicating when <code>X-RateLimit-Remaining</code> will return to its higher possible value</td>
</tr>
<tr>
<td><code>X-RateLimit-ResetSeconds</code></td>
<td>3599</td>
<td>How many seconds to wait before <code>X-RateLimit-Remaining</code> returns to its higher possible value</td>
</tr>
</tbody>
</table>


Resources
---------

For more targeted guides regarding API usage, and especially authentication, please
refer to [https://docs.funkwhale.audio/api.html](https://docs.funkwhale.audio/api.html)
