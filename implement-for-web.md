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

## Closed

| Feature | Where | Resolution |
|---|---|---|
| ✅ OAuth authorize for *third-party* apps | `/authorize` | Flutter consent UI (`OAuthAuthorizeScreen`) at `/authorize`; loads app via `GET /api/v1/oauth/apps/{client_id}/`, allow via `POST /api/v1/oauth/authorize` (AJAX → JSON `{code, redirect_uri}`), OOB shows copyable code, deny returns `error=access_denied`. Unauthenticated users are sent to `/login?from=…` and returned after sign-in. First-party Tayra login remains password token / OOB and is separate. |
