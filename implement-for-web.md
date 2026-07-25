| Feature | Where in Funkwhale | Escape hatch | Notes |
|---|---|---|---|
| Splash screen while loading WASM assets | n/a | n/a | WASM assets can take a while to load at first visit. Show some sort of splash screen while first load occurs on web. |
| Library admin (`/manage/library/*`) | Vue manage routes | Django admin + `funkwhale-manage` CLI | Edits, uploads browser, tags, libraries detail |
| Channels admin | `/manage/library/channels` | CLI / admin | |
| Instance settings | `/manage/settings` | Env vars, preferences API, Django admin | |
| User management UI | `/manage/users` | Django admin | |
| Signup | `/signup` | Disable open registration; invite via admin/CLI | |
| Password reset / email confirm | `/auth/password/*`, `/auth/email/confirm` | Email links still work if server sends them; no branded Tayra page | May need minimal static pages later |
| User profiles / activity | `/@username`, profile activity | N/A for private pods | Nice-to-have |
| Notifications | Vue notifications view | — | |
| PWA offline (Vue service worker) | Vue SW | Web is online-only | |

## Closed (not Tayra Flutter work)

| Feature | Where | Resolution |
|---|---|---|
| ✅ OAuth authorize for *third-party* apps | `/authorize` | Intentionally deferred — not first-party Tayra login. Stock Vue hosted a consent SPA that POSTed to `/api/v1/oauth/authorize`; nginx now serves Tayra `index.html` for `/authorize` and Tayra has no such route. API endpoints remain on the server. Tayra first-party auth uses `POST /api/v1/users/token/` (password) and/or OOB against a consent UI, separate from third-party app consent. See [doc/web-deferred-features.md](doc/web-deferred-features.md). |
