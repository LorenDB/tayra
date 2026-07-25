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
| No admin UI | Library admin, moderation, instance settings stay out of Tayra |
| No registration UI | Signup / password reset / email confirm stay out of band |
| Hard fork | `../funkwhale` on `tayra_front`: Vue removed; Tayra is the front image |

## Stock Funkwhale Vue surfaces not in Tayra web

| Feature | Where in Funkwhale | Escape hatch | Notes |
|---|---|---|---|
| Library admin (`/manage/library/*`) | Vue manage routes | Django admin + `funkwhale-manage` CLI | Edits, uploads browser, tags, libraries detail |
| Channels admin | `/manage/library/channels` | CLI / admin | |
| Instance settings | `/manage/settings` | Env vars, preferences API, Django admin | |
| Moderation (reports, domains, accounts, requests) | `/manage/moderation/*` | Django admin + moderator docs | Rare for small/private pods |
| User management UI | `/manage/users` | Django admin | |
| Signup | `/signup` | Disable open registration; invite via admin/CLI | |
| Password reset / email confirm | `/auth/password/*`, `/auth/email/confirm` | Email links still work if server sends them; no branded Tayra page | May need minimal static pages later |
| OAuth authorize for *third-party* apps | `/authorize` | Server API still has OAuth app registration + `/api/v1/oauth/authorize`; no in-band consent UI after Vue removal | Stock Vue hosted a consent SPA that POSTed to the authorize API; nginx now serves Tayra `index.html` for `/authorize`, and Tayra has no such route (auth redirects go to `/login`). **Not** django-allauth. Tayra first-party login uses `POST /api/v1/users/token/` (password) and/or OOB — separate from third-party app consent. |
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

## Possible later additions (not committed)

1. OAuth redirect callback (`/auth/callback`) instead of OOB paste on web (first-party only; not third-party consent)  
2. Third-party OAuth consent UI at `/authorize` if external apps need in-browser approve/deny again  
3. Upload path polish for browser file picker (upload may work partially already)  
4. Lightweight library cleanup UI if Django admin is too harsh  
5. Queue + listen-history persistence via IndexedDB  
6. Packaging as a custom Funkwhale `front` image (fork track) after drop-in is stable  

## Related docs

- Deploy notes: [web-deploy.md](web-deploy.md)
