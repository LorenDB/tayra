# Web deferred features

Tayra web is an **online-only**, **single-pod** primary UI meant to replace the
stock Funkwhale Vue SPA at `/`. This document lists surfaces that exist in
stock Funkwhale (or in native Tayra) but are **intentionally not** exposed in
the web client yet.

Use this as a backlog for future work. Ops escape hatches are noted where
relevant.

## Product constraints (by design)

| Constraint | Detail |
|---|---|
| Online-only | No offline audio cache, download queue, or local library DB on web |
| Single pod | `FUNKWHALE_URL` is compile-time; no multi-server picker |
| Limited admin UI | Library admin (libraries, uploads, tags, channels) when `permissions.library`; instance settings + user management when `permissions.settings`; moderation stays out |
| No registration UI | Email confirm stays out of band; signup + password reset are branded Tayra pages |
| Hard fork | `../funkwhale` on `tayra_front`: Vue removed; Tayra is the front image |

## Stock Funkwhale Vue surfaces not in Tayra web

| Feature | Where in Funkwhale | Escape hatch | Notes |
|---|---|---|---|
| Moderation (reports, domains, accounts, requests) | `/manage/moderation/*` | Django admin + moderator docs | Rare for small/private pods |
| Email confirm | `/auth/email/confirm` | Email links still work if server sends them; no branded Tayra page | Signup + password reset are implemented in Tayra |
| Plugins settings | `/settings/plugins` | Server-side plugin config | |
| Remote content / federation browser | `/content/remote` | Federation still runs server-side | No follow/scan UI in Tayra |
| Content libraries management | `/content/libraries` | Upload screen covers basic upload; not full library manager | |
| User profiles / activity | `/@username`, profile activity | N/A for private pods | Nice-to-have |
| Notifications | Vue notifications view | — | |
| Embed player | `embed.html` | Dropped with Vue | Re-add as static page if needed |
| PWA offline (Vue service worker) | Vue SW | Web is online-only | |
| Multi-server login | N/A (native Tayra has server field) | Native clients only | Web uses hardcoded pod |

## Native Tayra features disabled on web

| Feature | Reason |
|---|---|
| Offline downloads / audio file cache | Browser storage model; product decision |
| Download queue / Wi‑Fi-only policy | Same |
| Force offline mode | Online-only |
| Nextcloud backup / history sync | Relies on local DB + native paths |
| Android Auto / Wear OS | Platform-specific |
| Desktop window chrome / MPRIS | Desktop-only |
| Local cover-art file cache | Uses network images on web |
| Gemini Nano (on-device AI) | Android-only |

## Implemented in Tayra web (was deferred)

| Feature | Where | Notes |
|---|---|---|
| Signup | `/signup` | Branded form (username, email, password, confirm, optional invitation); `POST /api/v1/auth/registration/`; invite deep links `?invitation=`; success → `/login`. Invite creation stays admin/CLI. |
| User management | `/manage/users` | List/detail + invitations; PATCH name/active/quota/permissions; gated on `me.permissions.settings` / superuser. |
| Instance settings | `/manage/settings` | Section-grouped global prefs; `GET/POST bulk` admin settings API; bool/string/int/choice/multi-choice; file/complex read-only; gated on `me.permissions.settings`. |
| Channels admin | `/manage/library/channels` | List/detail/delete under Library admin; `GET/DELETE /api/v1/manage/channels/`; search, infinite scroll, stats; gated on `me.permissions.library`. |
| Library admin | `/manage/library/*` | Hub + libraries list/detail/edit/delete, uploads browser, tags CRUD, channels; gated on `me.permissions.library`. Server: first-party Tayra OAuth may use `instance:libraries`. |
| Splash while loading WASM/JS | `web/index.html` + `web/flutter_bootstrap.js` | AMOLED splash (Icon-192 + `#0992F2` spinner); removed on `flutter-first-frame`; slow-load status after 20s; external JS only for CSP. |
| OAuth authorize for *third-party* apps | `/authorize` | Flutter consent UI; `GET /api/v1/oauth/apps/{id}/` + `POST /api/v1/oauth/authorize`. First-party login stays password token / OOB. |

## Possible later additions (not committed)

1. OAuth redirect callback (`/auth/callback`) instead of OOB paste on web (first-party only; not third-party consent)  
2. Upload path polish for browser file picker (upload may work partially already)  
3. Lightweight library cleanup UI if Django admin is too harsh  
4. Queue + listen-history persistence via IndexedDB  
5. Packaging as a custom Funkwhale `front` image (fork track) after drop-in is stable  

## Related docs

- Deploy notes: [web-deploy.md](web-deploy.md)
