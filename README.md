# Tayra

Tayra is an opinionated Funkwhale client **and** a hard fork of [Funkwhale](https://funkwhale.audio) **1.4.1** that ships the client as the primary web SPA.

This monorepo contains:

1. **Tayra** (Flutter) at the **repository root** — Android / desktop / web client
2. **Funkwhale API** (`api/`) — Django server with first-party password → OAuth login
3. **Front image** (`front/`) — nginx that serves the compiled Flutter web SPA

You can still run the client alone with `flutter run` from the repo root.

## Client features

- AMOLED dark theme, all the time.
- Accent colors from album art when possible.
- Year-end reviews a la Spotify Wrapped.
- Download music for offline playback.
- And more!

Tayra supports most features of the official Funkwhale app (sometimes slightly buggier).

## Quick start — Flutter client

1. Install Flutter (stable) and required platform SDKs. See https://docs.flutter.dev.
2. From the repo root:

```bash
flutter pub get
flutter run
```

Against a local API:

```bash
flutter run -d chrome --dart-define=FUNKWHALE_URL=http://localhost:5000
```

Agent / contributor notes: [AGENTS.md](AGENTS.md). The Funkwhale API `schema.yml` is cached at the repo root for client work.

## Quick start — full stack (Docker)

```bash
git clone https://github.com/LorenDB/tayra.git
cd tayra
cp .env.example .env
# edit FUNKWHALE_HOSTNAME, FUNKWHALE_PROTOCOL, DJANGO_SECRET_KEY
mkdir -p data/music data/media data/static
docker compose up -d --build
```

Full details: **[DEPLOY.md](DEPLOY.md)**.

```bash
make up               # docker compose up -d --build
make front-rebuild    # rebuild SPA only (after hostname or client change)
make down
make logs
```

## Layout

| Path | Role |
|---|---|
| `lib/`, `android/`, `web/`, `pubspec.yaml`, … | **Tayra Flutter client** (repo root) |
| `api/` | Django / Funkwhale API (source build) |
| `front/` | nginx Dockerfile + proxy config (SPA built from root Flutter sources) |
| `docker-compose.yml` | Source-build stack |
| `.env.example` | Env template |
| `schema.yml` | Cached Funkwhale OpenAPI schema for client agents |

## Auth (this fork)

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

### Web SPA build

Web is **online-only**. The server URL is baked in at **build** time:

```bash
# Full stack image (preferred for deploy)
make front-rebuild
# or:
docker compose build front

# Client only
flutter build web --release \
  --dart-define=FUNKWHALE_URL=https://your.funkwhale.pod
```

- [doc/web-deploy.md](doc/web-deploy.md)
- [doc/web-deferred-features.md](doc/web-deferred-features.md)

## Ops without a Vue admin UI

| Task | Tool |
|---|---|
| Users / models | Django admin (`ADMIN_URL`) |
| Imports / federation | `manage.py` / Funkwhale CLI inside the API container |
| Background jobs | Celery worker + beat |

## Deferred

- Runtime-only pod URL via compose env (SPA URL is **build-time**; rebuild front after hostname changes)
- Admin / moderation / signup UIs in Tayra
- Upstream Vue frontend (removed)

See also [doc/web-deferred-features.md](doc/web-deferred-features.md).

## License

This monorepo (Flutter client and Funkwhale API/server stack) is licensed under
the **GNU Affero General Public License v3.0**. See [LICENSE](LICENSE).
