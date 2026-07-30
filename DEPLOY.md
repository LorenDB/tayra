# Deploy Funkwhale + Tayra (this fork)

Easy path: clone this monorepo and build images from source with Docker Compose.
The Flutter client lives at the repository root (no submodule). No stock
Funkwhale/Vue images required.

## Prerequisites

- Docker Engine + Docker Compose v2
- Enough disk for Flutter web build (~ a few GB during image build)
- A public hostname (or LAN name) for the pod

## 1. Clone

```bash
git clone https://github.com/LorenDB/tayra.git
cd tayra
```

The Flutter client is at the repository root (`pubspec.yaml`, `lib/`, …).

## 2. Configure environment

```bash
cp .env.example .env
```

Edit at least:

| Variable | Purpose |
|---|---|
| `FUNKWHALE_HOSTNAME` | Public host (e.g. `music.example.com`) |
| `FUNKWHALE_PROTOCOL` | Usually `https` |
| `DJANGO_SECRET_KEY` | Long random secret |

`FUNKWHALE_PROTOCOL` + `FUNKWHALE_HOSTNAME` are:

1. Used by the **API** at runtime (federation, absolute links)
2. Passed as a **build arg** when building the front image so Tayra bakes that
   URL into the SPA

> **Not implemented yet:** changing only compose/runtime env for the front
> without rebuilding. After a hostname change, rebuild front:
> `docker compose build --no-cache front && docker compose up -d front`

## 3. Build and start

From the **repository root** (the directory that contains `docker-compose.yml`
and `pubspec.yaml`):

```bash
test -f pubspec.yaml   # Flutter client at monorepo root

mkdir -p data/music data/media data/static
docker compose up -d --build
```

This builds (local tags only — never pulled from Docker Hub):

- `funkwhale-tayra-api:local` from `./api`
- `funkwhale-tayra-front:local` from `./front/Dockerfile` (compiles the root Flutter client)

If you see `pull access denied for funkwhale-tayra/api`, you are on an older
compose file that used a slash in the image name (Docker treated it as a Hub
path). Pull the latest compose from this fork and retry.

If you see `pubspec.yaml` missing from the build context, run compose from the
repository root (not from `front/` or `api/`).

Services: `postgres`, `redis`, `api`, `celeryworker`, `celerybeat`, `front`.

Default publish: `http://0.0.0.0:5000` → nginx (SPA + `/api/` proxy).

## 4. First-time Django setup

```bash
docker compose exec api python manage.py migrate
docker compose exec api python manage.py fw users create  # or createsuperuser
```

(Use whatever management commands your image exposes; stock Funkwhale uses
`funkwhale-manage` / `manage.py` depending on image entrypoint.)

Then open `https://your-hostname/` and sign in with **username + password**
(`POST /api/v1/users/token/`).

## 5. Migrating an existing stock compose stack

If you already run upstream Funkwhale with `image: funkwhale/api:…` and
`image: funkwhale/front:…`:

1. Back up Postgres and media.
2. Point your compose **build** at this repo (or copy this `docker-compose.yml`
   and `.env` patterns).
3. Replace image pulls with:

```yaml
api:
  build:
    context: ./api
    target: production
  image: funkwhale-tayra/api:local

front:
  build:
    context: .
    dockerfile: front/Dockerfile
    args:
      FUNKWHALE_URL: ${FUNKWHALE_PROTOCOL}://${FUNKWHALE_HOSTNAME}
  image: funkwhale-tayra/front:local
```

4. Keep the same `DATABASE_URL`, volume paths, and `FUNKWHALE_HOSTNAME`.
5. `docker compose up -d --build`

A `deploy/docker-compose.yml` with the same source-build layout is available if
you prefer the old `deploy/` directory name; run it with project directory =
repo root:

```bash
docker compose -f deploy/docker-compose.yml --project-directory . up -d --build
```

## 6. Updating

```bash
git pull
docker compose up -d --build
```

## Typesense / `ModuleNotFoundError: funkwhale_api.typesense`

Typesense is **optional**. You do not need the `typesense` compose profile for a normal
pod. The Django app lives at `api/funkwhale_api/typesense/`.

If API/celery crash with `No module named 'funkwhale_api.typesense'`:

1. Confirm the source tree has the package:
   ```bash
   ls api/funkwhale_api/typesense/__init__.py
   ```
2. Rebuild the API image without cache (stale layers / old dockerignore):
   ```bash
   docker compose build --no-cache api
   docker compose up -d api celeryworker celerybeat
   ```
3. You do **not** need to start the Typesense container unless you set
   `TYPESENSE_API_KEY` in `.env`.

A previous repo `.dockerignore` rule of bare `typesense` could exclude the Python
package from some builds; that rule is now limited to host data dirs only.

After client changes, rebuild the SPA image:

```bash
docker compose build --no-cache front && docker compose up -d front
# or:
make front-rebuild
```

## Makefile helpers

```bash
make up                      # docker compose up -d --build
make front-rebuild           # rebuild SPA image only
```

## Unimplemented / deferred

| Item | Notes |
|---|---|
| Runtime front/pod URL from compose env only | SPA URL is **build-time** (`FUNKWHALE_URL` arg). Rebuild front after hostname changes. |
| Runtime `config.js` / `window.location.origin` | Same family as above — not wired yet |
| Admin / moderation / signup UIs | Django admin + CLI; see Tayra `doc/web-deferred-features.md` |
| Stock Vue frontend | Removed in this fork |

## Troubleshooting

**API build: `cannot import name 'convert_path' from 'setuptools'`**  
Old `django-allauth` sdist vs new setuptools. The API Dockerfile pins
`setuptools==60.10.0` and uses `--no-build-isolation`. Rebuild with no cache:

```bash
docker compose build --no-cache api
```

**Login always “invalid username or password” (HTTP 400 on `/api/v1/users/token/`)**  
That response is from the **API**. After the auth fixes, the UI should show the
server’s real message (e.g. e-mail verification). Rebuild **api** and **front**:

```bash
docker compose build api front && docker compose up -d api front
```

Debug with curl (use your real host/user):

```bash
# password must be the transport digest, not plaintext:
# python3 -c "import hashlib; print(hashlib.sha256(b'tayra-login-v1\0'+b'YOUR_PASS').hexdigest())"
DIGEST=$(python3 -c "import hashlib; print(hashlib.sha256(b'tayra-login-v1\0'+b'YOUR_PASS').hexdigest())")
curl -sS -X POST "https://YOUR_HOST/api/v1/users/token/" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"YOUR_USER\",\"password\":\"$DIGEST\"}" | jq .
```

- `200` + `access_token` → API OK; rebuild front if the app still fails  
- `400` with `Unable to log in…` / `invalid_credentials` → wrong user/password, wrong DB, API image not this fork, or password was set before transport hashing (reset once with `fw users update USER --password '…'`)  
- `400` / `password_not_hashed` → body still has plaintext; use the digest above or a current Tayra build  
- `400` / `email_unverified` → verify e-mail or set `ACCOUNT_EMAIL_VERIFICATION_ENFORCE=false`  
- `400` / `missing_credentials` → body not parsed (Content-Type / proxy stripping POST)  
- HTML / `Invalid HTTP_HOST header` → `FUNKWHALE_HOSTNAME` / `DJANGO_ALLOWED_HOSTS` mismatch  
- Connection errors → `FUNKWHALE_URL` baked into the SPA doesn’t match how you open the site

Also check API logs while reproducing (look for `token_login`, not only
`Bad Request`):

```bash
docker compose logs -f api 2>&1 | grep -E 'token_login|Bad request|Bad Request'
```

A failed login with body size **151** is almost always:

```json
{"error":"invalid_credentials","detail":"Unable to log in with provided credentials",...}
```

That means the API **did** parse username/password; the password check failed
against the database the API is using. The next log line includes
`user_found=…`, `has_usable_password=…`, `user_count=…`, and `meta=…`.

**Verify the API is using your existing DB and password hashes:**

```bash
# How many users does this API see?
docker compose exec api python manage.py shell -c \
  "from django.contrib.auth import get_user_model; U=get_user_model(); print('users', U.objects.count()); print(list(U.objects.values_list('username', flat=True)[:20]))"

# Does this password match for a known account? (does not print the password)
docker compose exec api python manage.py shell -c \
  "from django.contrib.auth import get_user_model; u=get_user_model().objects.filter(username__iexact='YOUR_USER').first(); print('found', u); print('usable', u.has_usable_password() if u else None); print('check', u.check_password('YOUR_PASS') if u else None)"
```

- `users 0` or missing username → **`DATABASE_URL` / Postgres volume is not your old pod DB** (common after a “from scratch” recreate). Point compose at the old database or restore a dump; do not expect old passwords in an empty DB.
- `found <user>`, `check False`, `usable True` → wrong password for that row (or hash from another instance). Reset:  
  `docker compose exec api python manage.py fw users update YOUR_USER --password 'new-pass'`
- `usable False` → no local password (LDAP/social only). Set `LDAP_*` like the old pod, or set a local password with the command above.

### OIDC single sign-on (optional)

Tayra can act as an OpenID Connect relying party so users sign in with an
external IdP. After SSO, the IdP **username claim** (default
`preferred_username`) is matched to an existing local `User.username`
(case-insensitive). Password login remains available.

1. Register a confidential OIDC client at your IdP with redirect URI:
   ```
   {FUNKWHALE_PROTOCOL}://{FUNKWHALE_HOSTNAME}/api/v1/users/oidc/callback/
   ```
2. Either set env vars (and restart the API) **or** configure under
   **Settings → Instance settings** (`users` section):

   | Env | Instance preference | Notes |
   |---|---|---|
   | `OIDC_ENABLED` | `users__oidc_enabled` | Either path can enable SSO |
   | `OIDC_DISCOVERY_URL` | `users__oidc_discovery_url` | Issuer or discovery URL |
   | `OIDC_CLIENT_ID` | `users__oidc_client_id` | |
   | `OIDC_CLIENT_SECRET` | `users__oidc_client_secret` | Prefer env for secrets |
   | `OIDC_SCOPES` | `users__oidc_scopes` | Default `openid profile email` |
   | `OIDC_USERNAME_CLAIM` | `users__oidc_username_claim` | Default `preferred_username` |
   | `OIDC_DISPLAY_NAME` | `users__oidc_display_name` | Login button label |
   | `OIDC_AUTO_CREATE` | `users__oidc_auto_create` | Off = match existing users only |

3. Ensure local usernames match the IdP claim values (or enable auto-create).
4. Clients discover SSO via `GET /api/v1/users/auth-methods/` and show
   **Sign in with …** on the login screen.

**“Passwords in the browser Network tab”**  
Tayra sends a **SHA-256 transport digest** in the `password` field (not the
account password). DevTools still shows the JSON body after TLS decryption;
you should see a 64-character hex string, not the typed password. Ensure users
open the site via **HTTPS**. If you see plaintext there, the SPA build is too
old—rebuild `front`.
**Browser CSP / CanvasKit blocked (gstatic.com)**  
The front image must build with `--no-web-resources-cdn` (already in
`front/Dockerfile`) so CanvasKit is same-origin. Rebuild front:

```bash
docker compose build --no-cache front && docker compose up -d front
```

**Front build fails (Flutter)**  
Ensure you are at the monorepo root (`ls pubspec.yaml`) and that Flutter
sources (`lib/`, `web/`, `assets/`) are present in the build context.

**Login hits wrong host**  
Rebuild front with the correct `FUNKWHALE_HOSTNAME` / `FUNKWHALE_PROTOCOL` in `.env`.

**API 502**  
`front` proxies to service name `api` on port `5000` (uWSGI inside the API image). Check `docker compose logs api`.
