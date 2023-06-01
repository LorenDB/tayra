/// <reference lib="webworker" />

import { cleanupOutdatedCaches, precacheAndRoute } from 'workbox-precaching'
import { NetworkFirst } from 'workbox-strategies'
import { ExpirationPlugin } from 'workbox-expiration'
import { registerRoute } from 'workbox-routing'
import { clientsClaim } from 'workbox-core'

declare let self: ServiceWorkerGlobalScope

// NOTE: Clean up outdated caches
//       With each new production build, all precached assets
//       that were modified are added to the cache. The old versions
//       need to be removed manually.
cleanupOutdatedCaches()

// Let new service worker claim control of already open web pages
// https://developer.chrome.com/docs/workbox/modules/workbox-core/#clients-claim
clientsClaim()

// Support for an update prompt handled by VitePWA:
// https://vite-plugin-pwa.netlify.app/guide/prompt-for-update.html
self.addEventListener('message', (event) => {
  if (event.data?.type === 'SKIP_WAITING') {
    return self.skipWaiting()
  }
})

// NOTE: Network-First cache for API calls
//       We're using cache only when the user goes offline
registerRoute(({ url }) => {
  if (url.pathname.startsWith('/api/v1/listen')) return false
  return url.pathname.startsWith('/api/v1')
}, new NetworkFirst({
  cacheName: 'API Routes',
  plugins: [
    // Expire after a week
    new ExpirationPlugin({ maxAgeSeconds: 7 * 24 * 3600 })
  ]
}))

// Precache all assets and add routes for them
// https://developer.chrome.com/docs/workbox/reference/workbox-precaching/#method-precacheAndRoute
precacheAndRoute(self.__WB_MANIFEST)
