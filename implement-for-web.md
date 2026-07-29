| Feature | Where in Funkwhale | Escape hatch | Notes |
|---|---|---|---|
| Signup | `/signup` | Disable open registration; invite via admin/CLI | |
| Password reset | `/auth/password/reset`, `/auth/password/reset/confirm` | ✅ Branded Tayra UI (request + confirm from email link) | Email confirm still out of band |
| Email confirm | `/auth/email/confirm` | Email links still work if server sends them; no branded Tayra page | May need minimal static pages later |
| User profiles / activity | `/@username`, profile activity | N/A for private pods | Nice-to-have |
| Notifications | Vue notifications view | — | |
| PWA offline (Vue service worker) | Vue SW | Web is online-only | |

## Closed

| Feature | Where | Resolution |
|---|---|---|
| ✅ User management UI | `/manage/users` | Permission-gated list/detail (`/manage/users`, `/manage/users/:id`) + invitations (`/manage/users/invitations`). Settings entry when `me.permissions.settings`/superuser. PATCH name, is_active, upload_quota, permissions; staff/superuser confirm; self-deactivation double-confirm. Invitation create (empty POST), copy, delete via `invitations/action/`. |
| ✅ Instance settings | `/manage/settings` | Permission-gated section-grouped prefs UI; `GET /api/v1/instance/admin/settings/` + `POST …/bulk/`; bool/string/int/choice/multi-choice editable; file/complex read-only. Gated on `me.permissions.settings`. |
| ✅ Channels admin | `/manage/library/channels` | Permission-gated list/detail/delete under Library admin; `GET/DELETE /api/v1/manage/channels/`, search + infinite scroll, stats on detail. Reuses `canManageLibrary`. |
| ✅ Library admin (`/manage/library/*`) | Vue manage routes | Permission-gated hub + libraries (list/detail/edit/delete), uploads browser, tags CRUD. First-party Tayra OAuth exception for `instance:libraries` when user has `permission_library`. |
| ✅ Splash screen while loading WASM assets | n/a (pre-Flutter HTML) | Branded AMOLED splash in `web/index.html` (logo + `#0992F2` spinner); CSP-safe `web/flutter_bootstrap.js` removes it on `flutter-first-frame`, shows “Still loading…” after 20s. Auth `/splash` route unchanged. |
| ✅ OAuth authorize for *third-party* apps | `/authorize` | Flutter consent UI (`OAuthAuthorizeScreen`) at `/authorize`; loads app via `GET /api/v1/oauth/apps/{client_id}/`, allow via `POST /api/v1/oauth/authorize` (AJAX → JSON `{code, redirect_uri}`), OOB shows copyable code, deny returns `error=access_denied`. Unauthenticated users are sent to `/login?from=…` and returned after sign-in. First-party Tayra login remains password token / OOB and is separate. |
