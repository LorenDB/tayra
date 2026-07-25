# Deploying Tayra web as the Funkwhale primary UI

> **Hard fork:** the sibling `../funkwhale` tree on branch `tayra_front` has
> **removed Vue** and builds the front image from Tayra. Prefer
> `make front-image` there. This doc still describes drop-in / sibling builds.

Tayra builds a Flutter web SPA that is the **primary** UI for the forked
Funkwhale reverse-proxy document root.

## Build

From the **Funkwhale fork** (recommended):

```bash
cd ../funkwhale
make front-image FUNKWHALE_URL=https://your.funkwhale.pod
# → builds Tayra into front/dist and tags funkwhale/front:tayra
```

From the Tayra repo alone:

```bash
flutter build web \
  --release \
  --no-web-resources-cdn \
  --dart-define=FUNKWHALE_URL=https://your.funkwhale.pod
```

`--no-web-resources-cdn` is required behind Funkwhale’s CSP (`script-src 'self'`):
otherwise the browser blocks CanvasKit from `gstatic.com`.

Artifacts: `build/web/` (or `../funkwhale/front/dist/`).

Notes:

- `FUNKWHALE_URL` enables branded single-pod login.
- Prefer same-origin with `/api/`.
- Path URL strategy is on for nginx `try_files`.
- Auth: `POST /api/v1/users/token/` (username/password → OAuth tokens).

## Drop-in on stock Funkwhale

Stock compose uses a `front` service (nginx) that:

1. Proxies `/api/`, `/federation/`, `/rest/`, `/.well-known/`, etc. to the API
2. Serves SPA files from `/usr/share/nginx/html` with `try_files … /index.html`

### Option 1 — volume mount over the Vue assets

After `flutter build web`, mount `build/web` over the front container’s HTML
root (exact path depends on your image; often `/usr/share/nginx/html`):

```yaml
# example fragment — adapt to your compose file
services:
  front:
    volumes:
      - /path/to/tayra/build/web:/usr/share/nginx/html:ro
      # keep existing media/music mounts as in stock deploy
```

### Option 2 — rsync / CI copy

Copy `build/web/*` into the directory your reverse proxy uses as the SPA root.
Rollback = restore the previous Vue build.

### Optional SPA HTML injection

If you care about Open Graph / title injection via Django middleware:

```env
FUNKWHALE_SPA_HTML_ROOT=/usr/share/nginx/html/index.html
# or a file:// path the API process can read
```

Not required for authenticated listening.

## What stays on the API

- OAuth app registration + token endpoints
- Scoped listen tokens (`GET /api/v1/users/me/` → `tokens.listen`) for stream URLs
- Media streaming, federation, Celery, Subsonic

Third-party OAuth consent at `/authorize` is intentionally **not** implemented in Tayra (Vue consent SPA is gone; first-party login uses password token and/or OOB). See [web-deferred-features.md](web-deferred-features.md).

## Ops without Vue admin

| Task | Tool |
|---|---|
| Users / some models | Django admin (`ADMIN_URL`) |
| Imports, federation | `funkwhale-manage` CLI |
| Instance prefs | Env + Django |

See [web-deferred-features.md](web-deferred-features.md) for the full gap list.

## Local smoke test

```bash
# Against a real pod (CORS is open on stock Funkwhale; same-origin is better)
flutter run -d chrome \
  --dart-define=FUNKWHALE_URL=https://your.funkwhale.pod
```

Or serve `build/web` with any static server behind the same host as the API.
