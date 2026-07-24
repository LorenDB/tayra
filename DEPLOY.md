# Deploy Funkwhale + Tayra (this fork)

Easy path: clone the fork, pull the Tayra submodule, build images from source
with Docker Compose. No stock Funkwhale/Vue images required.

## Prerequisites

- Docker Engine + Docker Compose v2
- Enough disk for Flutter web build (~ a few GB during image build)
- A public hostname (or LAN name) for the pod

## Push order (maintainers)

If you maintain both repos:

1. **Push Tayra first** (`github.com/LorenDB/tayra` or your fork) including web /
   password-login support
2. In this repo: `cd tayra && git pull origin master && cd .. && git add tayra`
3. Commit the submodule pointer and push the Funkwhale fork

Clones only see the submodule SHA you pin. Docker `COPY tayra/` uses that
commit’s tree (not uncommitted local edits on the maintainer machine).

## 1. Clone with submodule

```bash
git clone --recurse-submodules https://github.com/YOU/funkwhale-fork.git
cd funkwhale-fork
```

If you already cloned without submodules:

```bash
git submodule update --init --recursive
```

Tayra lives at `./tayra` (see `.gitmodules`).

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
and the `tayra/` folder):

```bash
# Required if tayra/ is empty (submodule not checked out)
git submodule update --init --recursive
test -f tayra/pubspec.yaml   # should succeed

mkdir -p data/music data/media data/static
docker compose up -d --build
```

This builds (local tags only — never pulled from Docker Hub):

- `funkwhale-tayra-api:local` from `./api`
- `funkwhale-tayra-front:local` from `./front/Dockerfile` (compiles `./tayra`)

If you see `pull access denied for funkwhale-tayra/api`, you are on an older
compose file that used a slash in the image name (Docker treated it as a Hub
path). Pull the latest compose from this fork and retry.

If you see `COPY tayra/... not found`, the submodule is empty — run the
`git submodule update --init --recursive` line above.

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
git submodule update --init --recursive
docker compose up -d --build
```

After a Tayra release, bump the submodule:

```bash
cd tayra && git pull origin master && cd ..
git add tayra && git commit -m "Bump Tayra submodule"
docker compose build --no-cache front && docker compose up -d front
```

## Makefile helpers

```bash
make submodule-init          # git submodule update --init --recursive
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

**Front build fails (Flutter)**  
Ensure `tayra/` is populated (`ls tayra/pubspec.yaml`). Re-init submodules.

**Login hits wrong host**  
Rebuild front with the correct `FUNKWHALE_HOSTNAME` / `FUNKWHALE_PROTOCOL` in `.env`.

**API 502**  
`front` proxies to service name `api` on port `5000` (uWSGI inside the API image). Check `docker compose logs api`.
