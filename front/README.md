# Front image (Tayra SPA + nginx)

Vue is gone. The front image is built from the **repo root**:

```bash
docker compose build front
```

That runs `front/Dockerfile`, which:

1. Compiles the Flutter client at the monorepo root with Flutter web
2. Packs the result into nginx with the stock Funkwhale proxy layout

## Build args

| Arg | Source | Meaning |
|---|---|---|
| `FUNKWHALE_URL` | compose: `${FUNKWHALE_PROTOCOL}://${FUNKWHALE_HOSTNAME}` | Baked into Tayra at **build** time |

Changing hostname later → `docker compose build --no-cache front`.

## Local Flutter (optional)

```bash
# From monorepo root
flutter build web --release --dart-define=FUNKWHALE_URL=https://…
```

Prefer compose for deploy; see [DEPLOY.md](../DEPLOY.md).
