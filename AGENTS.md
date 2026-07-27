# Funkwhale + Tayra fork — Agent Guidelines

Fork of Funkwhale 1.4.1: **replaces the Vue.js UI with Tayra** (Flutter web submodule).
The `tayra/` submodule is the Flutter client; everything else is the Django API/server stack.

## Repo layout

| Path | Role |
|---|---|
| `api/` | Django / Funkwhale API (Python, Poetry) |
| `front/` | nginx Dockerfile that compiles `tayra/` into a web SPA |
| `tayra/` | **Git submodule** — Tayra Flutter client |
| `docker-compose.yml` | Production source-build stack |
| `dev.yml` | Local dev compose (API only; Tayra runs separately) |
| `changes/changelog.d/` | Towncrier changelog fragments (CI requires one) |

## Coordinated client+server development

The `tayra/` submodule is pinned to a specific commit. When working on both repos,
clone Tayra as a **sibling directory** (`../tayra/`) and develop there:

```bash
# Clone if it doesn't exist yet
test -d ../tayra || git clone https://github.com/LorenDB/tayra.git ../tayra

# Run API in dev mode
docker compose -f dev.yml up -d

# Run Tayra from sibling dir against local API
cd ../tayra
flutter pub get
flutter run -d chrome --dart-define=FUNKWHALE_URL=http://localhost:5000
```

Keep the submodule at `tayra/` as the pinned reference — commit submodule pointer
updates (`git add tayra && git commit`) after merging upstream Tayra changes.

## Full-stack compose commands

```bash
make submodule-init    # git submodule update --init --recursive
make up               # docker compose up -d --build (full stack)
make front-rebuild    # rebuild SPA only (after hostname or Tayra change)
make down             # docker compose down
make logs             # follow all logs
```

## Key gotchas

- **`FUNKWHALE_URL` is build-time.** The server URL is baked into the SPA. After
  hostname changes: `make front-rebuild`.
- **Submodule must be checked out.** `tayra/pubspec.yaml` must exist before
  `docker compose build front`.
- **First-party login** (this fork's addition): `POST /api/v1/users/token/`
  with `{"username","password"}` → OAuth tokens + `listen_token`.
- **First-time setup:** `docker compose exec api python manage.py migrate`
  then `docker compose exec api python manage.py fw users create`.

## API (Django) commands

```bash
cd api
poetry install                   # install deps
poetry run pytest tests          # run tests
poetry run pylint --recursive=true config funkwhale_api tests   # lint
```

## Tayra client conventions

Detailed guidelines in `tayra/AGENTS.md`. Essentials:
- **Package-only imports** (`package:tayra/...`), never relative
- Riverpod for state management
- Hand-written models with `fromJson()` (no code generation)
- `flutter analyze` before committing, `dart format lib/ test/`

## Pre-commit

`.pre-commit-config.yaml` runs: black, isort, flake8, codespell, prettier,
pyupgrade, shellcheck, poetry lock check. Must pass before commit.
