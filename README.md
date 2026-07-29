# Funkwhale + Tayra (hard fork)

Fork of [Funkwhale](https://funkwhale.audio) **1.4.1** that:

1. **Removes the Vue.js web UI**
2. Serves **[Tayra](https://github.com/LorenDB/tayra)** (Flutter web) as the primary SPA (git submodule)
3. Adds **first-party password → OAuth token** login (`POST /api/v1/users/token/`)
4. **Builds from source** via Docker Compose (no stock prebuilt front/api required)

## Quick deploy

```bash
git clone --recurse-submodules https://github.com/YOU/this-fork.git
cd this-fork
cp .env.example .env
# edit FUNKWHALE_HOSTNAME, FUNKWHALE_PROTOCOL, DJANGO_SECRET_KEY
mkdir -p data/music data/media data/static
docker compose up -d --build
```

Full details: **[DEPLOY.md](DEPLOY.md)**.

## Layout

| Path | Role |
|---|---|
| `api/` | Django / Funkwhale API (source build) |
| `front/` | nginx Dockerfile + proxy config (SPA built from Tayra) |
| `tayra/` | **Git submodule** — Tayra client |
| `docker-compose.yml` | Source-build stack (use this) |
| `.env.example` | Env template |

## Auth

```http
POST /api/v1/users/token/
{"username": "…", "password": "<sha256 hex transport digest>"}
```

The `password` field is **not** the account password in plaintext. Tayra sends a
domain-separated SHA-256 digest (`tayra-login-v1` + NUL + password); the API
rejects non-digest values. See `api/funkwhale_api/users/password_transport.py`.

Returns access/refresh tokens, client credentials for refresh, and `listen_token`
for media URLs.

**Upgrade note:** passwords set before this change need a one-time reset
(`fw users update USER --password '…'` or the password-reset email flow) so the
stored hash matches the transport scheme.
## Ops without a Vue admin UI

| Task | Tool |
|---|---|
| Users / models | Django admin (`ADMIN_URL`) |
| Imports / federation | `manage.py` / Funkwhale CLI inside the API container |
| Background jobs | Celery worker + beat |

## Deferred (not in this package yet)

- Runtime-only pod URL via compose env (SPA URL is **build-time**; rebuild front after hostname changes)
- Admin / moderation / signup UIs in Tayra
- Upstream Vue frontend (removed)

See also Tayra’s `doc/web-deferred-features.md` in the submodule.

## License

AGPL (upstream Funkwhale). Tayra has its own license in the submodule.
