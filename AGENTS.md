# Tayra monorepo — Agent Guidelines

Monorepo combining:

1. **Tayra** — Flutter/Dart music player client for Funkwhale (repo root)
2. **Funkwhale + Tayra fork** — Django API / server stack that replaces Vue with the Tayra web SPA

Android-primary client with desktop (Linux/Windows) and web support. OAuth authentication, audio playback (`just_audio` + `audio_service`), AMOLED dark theme.

**Flutter package name:** `tayra`  
**Flutter lives at the repository root** — run `flutter run` / `flutter test` from `/`, not a subdirectory.

## Repo layout

| Path | Role |
|---|---|
| `lib/`, `android/`, `web/`, `pubspec.yaml`, … | Tayra Flutter client |
| `api/` | Django / Funkwhale API (Python, Poetry) |
| `front/` | nginx Dockerfile that compiles root Flutter sources into a web SPA |
| `docker-compose.yml` | Production source-build stack |
| `dev.yml` | Local dev compose (API only; run Flutter separately) |
| `schema.yml` | Cached Funkwhale OpenAPI schema for the client |

## Coordinated client + server development

```bash
# API in dev mode
docker compose -f dev.yml up -d

# Client from repo root against local API
flutter pub get
flutter run -d chrome --dart-define=FUNKWHALE_URL=http://localhost:5000
```

## Full-stack compose commands

```bash
make up               # docker compose up -d --build (full stack)
make front-rebuild    # rebuild SPA only (after hostname or client change)
make down             # docker compose down
make logs             # follow all logs
```

## Key gotchas

- **`FUNKWHALE_URL` is build-time.** The server URL is baked into the SPA. After hostname changes: `make front-rebuild`.
- **Flutter sources are at repo root.** `pubspec.yaml` must exist at `/` before `docker compose build front`.
- **First-party login** (this fork's addition): `POST /api/v1/users/token/` with `{"username","password"}` → OAuth tokens + `listen_token`. `password` must be the domain-separated SHA-256 transport digest (never plaintext); see `password_transport` on API and client.
- **OIDC SSO** (optional): env `OIDC_*` and/or instance prefs `users__oidc_*`. Server is the OIDC RP; clients use `GET /api/v1/users/auth-methods/`, then `/users/oidc/login/` → IdP → callback → `POST /users/oidc/token/`. Username claim (default `preferred_username`) matches local `User.username`. See `DEPLOY.md`.
- **First-time setup:** `docker compose exec api python manage.py migrate` then `docker compose exec api python manage.py fw users create`.

## API (Django) commands

```bash
cd api
poetry install                   # install deps
poetry run pytest tests          # run tests
poetry run pylint --recursive=true config funkwhale_api tests   # lint
```

## Pre-commit (server side)

`.pre-commit-config.yaml` runs: black, isort, flake8, codespell, prettier, pyupgrade, shellcheck, poetry lock check. Must pass before commit when touching API/server files.

---

# Tayra client guidelines

Flutter/Dart music player client. Uses OAuth authentication, audio playback (`just_audio` + `audio_service`), AMOLED dark theme.

**Package:** `tayra`

## API Reference

The Swagger schema for the Funkwhale server API is in `schema.yml` at the repo root.

## Build & Deploy

```bash
# Build + install + launch (combined)
flutter build apk --debug && \
  adb install -r build/app/outputs/flutter-apk/app-debug.apk && \
  adb shell am start -n dev.lorendb.tayra/.MainActivity

# Analysis & formatting
flutter analyze
dart format lib/ test/
```

## Testing

```bash
flutter test                                             # all tests
flutter test test/path/to/test_file.dart                 # single file
flutter test test/path/to/test_file.dart --name "name"   # single test by name
```

Test coverage is minimal (placeholder only). Add tests for new features: widget tests for screens, unit tests for business logic. Place tests in `test/` mirroring `lib/` structure; name files `*_test.dart`. Use `flutter_test` and `mockito`.

## Project Structure

```
lib/
├── core/
│   ├── api/          # API client (dio), models (hand-written), cached repository
│   ├── auth/         # OAuth authentication providers
│   ├── cache/        # Offline cache manager, audio cache, download queue
│   ├── layout/       # Responsive layout helpers
│   ├── router/       # go_router configuration
│   ├── theme/        # AppTheme constants, gradients, dark theme
│   └── widgets/      # Reusable components (TrackListTile, CoverArtWidget, ShimmerList)
└── features/         # Feature-first modules
    ├── auth/         # Login screen
    ├── browse/       # Albums, artists, detail screens, paginated grid
    ├── favorites/    # Favorites screen & provider
    ├── home/         # Home screen
    ├── player/       # Player UI, provider (1600+ lines), queue, mini player, now playing
    ├── playlists/    # Playlists screen, detail, add-to-playlist sheet
    ├── radios/       # Radio stations
    ├── search/       # Search screen
    ├── settings/     # Settings screen & provider
    └── year_review/  # Year-in-review, listen history
```

## Code Style

### Imports — Package Only (Never Relative)
```dart
import 'package:flutter/material.dart';         // 1. Flutter SDK
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 2. Third-party
import 'package:tayra/core/api/models.dart';     // 3. Local (package:tayra/...)
```
Never use relative imports like `../../core/api/models.dart`.

### Naming
- **Files:** `snake_case` — suffixed `*_screen.dart`, `*_provider.dart`, `*_widget.dart`
- **Classes:** `PascalCase` — private classes prefixed with `_` (e.g. `_AlbumHeader`)
- **Variables/functions:** `camelCase` — private members prefixed with `_`
- **Constants:** `lowerCamelCase` with `static const`

### Section Dividers
Use decorative comment dividers for logical grouping:
```dart
// ── Providers ───────────────────────────────────────────────────────
```

### Formatting
- Lint rules: `package:flutter_lints/flutter.yaml` (see `analysis_options.yaml`)
- Use `const` constructors wherever possible
- Use `dart format .` in project root before committing

## State Management (Riverpod)

- `StateNotifierProvider` — mutable state with business logic (e.g. `playerProvider`)
- `FutureProvider` / `FutureProvider.family` — async data loading with parameters
- `Provider` — services/singletons (dependency injection, e.g. `funkwhaleApiProvider`)
- Use `ref.watch()` for reactive rebuilds, `ref.read()` for one-time access
- Use `ref.invalidate()` for pull-to-refresh patterns
- Immutable state classes with `copyWith()` pattern

## Widget Patterns

- Use `ConsumerWidget` or `ConsumerStatefulWidget` for widgets reading providers
- Screen file layout: providers at top, public screen class, then private `_` widgets
- Reusable widgets go in `core/widgets/`

## Error Handling

- **UI:** Use `AsyncValue.when(loading:, error:, data:)` for declarative handling
- **Optimistic updates:** Apply state change immediately, revert in `catch` block
- **Non-critical operations:** Silently catch failures (e.g. telemetry, analytics)
- **Null safety:** Use `?` and `??` extensively; avoid force unwrap (`!`)

## Models

Hand-written in `lib/core/api/models.dart` with `factory fromJson()` constructors (no code generation). Defensive JSON parsing helpers (`_toMap`, `_toMapOrNull`, `_toListOfMaps`) handle inconsistent Funkwhale API responses.

## Theme

Use `AppTheme.*` constants (defined in `core/theme/app_theme.dart`) — never hardcode colors. AMOLED black background (`0xFF000000`), primary blue (`0xFF0992F2`), teal accent (`0xFF00D4AA`).

Accessibility note: there's a user setting to disable dynamic album accent colors. It's implemented in `lib/features/settings/settings_provider.dart` as `useDynamicAlbumAccent` and exposed in the Settings UI (`lib/features/settings/settings_screen.dart`). Palette generation in `lib/core/theme/palette_provider.dart` respects this flag and returns `AppTheme.primary` when disabled. If we later decide to rework or reintroduce accent color behavior, update these files accordingly.

## Key Dependencies

| Category | Package |
|---|---|
| State | flutter_riverpod, riverpod_annotation |
| Navigation | go_router |
| HTTP | dio |
| Audio | just_audio, audio_service, just_audio_media_kit |
| Storage | flutter_secure_storage, shared_preferences, sqflite |
| UI | cached_network_image, shimmer, palette_generator, google_fonts |
| Analytics | aptabase_flutter |

## Analytics (Aptabase)

- Log only basic, non-identifying usage statistics
- Do NOT log user-identifying information
- When adding new features, be sure to consider if you should proactively insert non-PII collecting Aptabase calls if they could be useful to help developers understand which features are being used

## Android Notes

- `MainActivity` extends `AudioServiceActivity` (required for audio_service)
- Permissions: INTERNET, WAKE_LOCK, FOREGROUND_SERVICE, FOREGROUND_SERVICE_MEDIA_PLAYBACK
- Network security config allows cleartext HTTP for localhost (dev only)
- Android Auto browse tree support in `player_provider.dart`
- Android SQL doesn't necessarily have as many features available as other platforms, so be sure to use Android-compatible SQL statements
