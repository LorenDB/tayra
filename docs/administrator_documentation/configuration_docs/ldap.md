# Configure LDAP

{abbr}`LDAP (Lightweight Directory Access Protocol)` is a protocol for providing directory services. It acts as a central authority for user login information. Funkwhale supports LDAP through the [Django LDAP authentication module](https://django-auth-ldap.readthedocs.io/).

```{important}
LDAP users can't change their password in the app.
```

## Dependencies

LDAP support requires extra dependencies. We include these in our requirements files to make it easier to set up. If you aren't using LDAP, you can safely remove these.

```{dropdown} OS dependencies

- `libldap2-dev`
- `libsasl2-dev`

```

```{dropdown} Python dependencies

- `python-ldap`
- `python-django-auth-ldap`

```

## Environment variables

You can configure LDAP authentication using environment variables in your `.env` file.

### Basic features

```{py:data} LDAP_ENABLED
---
value: True
type: Boolean
---

Set this to `True` to enable LDAP support
```

```{py:data} LDAP_SERVER_URI
---
type: URI
value: ldap://my.host:389
---

The LDAP {abbr}`URI (Uniform Resource Identifier)` of your authentication server.
```

```{py:data} LDAP_BIND_DN
---
type: String
value: cn=admin,dc=domain,dc=com
---

LDAP user {abbr}`DN (Distinguised Name)` to bind on so you can perform searches.
```

```{py:data} LDAP_BIND_PASSWORD
---
type: String
value: bindpassword
---

LDAP user password for bind {abbr}`DN (Distinguised Name)`.
```

```{py:data} LDAP_SEARCH_FILTER
---
type: String
value: (|(cn={0})(mail={0}))
---

The LDAP user filter, using `{0}` as the username placeholder. Uses standard [LDAP search syntax](https://social.technet.microsoft.com/wiki/contents/articles/5392.active-directory-ldap-syntax-filters.aspx).
```

```{py:data} LDAP_START_TLS
---
type: Boolean
value: False
---

Set to `True` to enable LDAP StartTLS support.
```

```{py:data} LDAP_ROOT_DN
---
type: String
value: dc=domain,dc=com
---

The LDAP search root {abbr}`DN (Distinguised Name)`. Supports several entries in a comma-delimited list.
```

```{py:data} LDAP_USER_ATTR_MAP
---
type: String
value: first_name:givenName, last_name:sn, username:cn, email:mail
---

A mapping of Django user attributes to LDAP values.
```

```{py:data} AUTH_LDAP_BIND_AS_AUTHENTICATING_USER
---
type: Boolean
value: False
---

Controls whether to use direct binding.
```

### Group features

LDAP provides extra features for working with groups. Group configuration is an advanced feature. Most users don't need to configure these settings.

```{seealso}
[Django's LDAP documentation](https://django-auth-ldap.readthedocs.io/en/latest/groups.html) for groups.
```

```{py:data} LDAP_GROUP_DN
---
type: String
value: ou=groups,dc=domain,dc=com
---

The LDAP group search root {abbr}`DN (Distinguised Name)`. This needs to be set to `True` to enable group features.
```

```{py:data} LDAP_GROUP_FILTER
---
type: String
value: objectClass=groupOfNames
---

The LDAP group filter.
```

```{py:data} LDAP_REQUIRE_GROUP
---
type: String
value: cn=enabled,ou=groups,dc=domain,dc=com
---

The group that users need to be a member of to authenticate.
```

```{py:data} LDAP_DENY_GROUP
---
type: String
value: cn=disabled,ou=groups,dc=domain,dc=com
---

A group whose members can't authenticate.
```
