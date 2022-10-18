import { defineConfig } from 'vite'
import Vue from '@vitejs/plugin-vue'
import Inspector from 'vite-plugin-vue-inspector'
import { VitePWA } from 'vite-plugin-pwa'
import { resolve } from 'path'

const port = +(process.env.VUE_PORT ?? 8080)

// https://vitejs.dev/config/
export default defineConfig(({ mode }) => ({
  envPrefix: ['VUE_', 'FUNKWHALE_SENTRY_'],
  plugins: [
    // https://github.com/vitejs/vite/tree/main/packages/plugin-vue
    Vue(),

    // https://github.com/webfansplz/vite-plugin-vue-inspector
    Inspector({
      toggleComboKey: 'alt-shift-d'
    }),

    // https://github.com/antfu/vite-plugin-pwa
    VitePWA({
      strategies: 'injectManifest',
      srcDir: 'src',
      filename: 'serviceWorker.ts',
      manifestFilename: 'manifest.json',
      devOptions: {
        enabled: true,
        type: 'module',
        navigateFallback: 'index.html'
      },
      manifest: {
        name: 'Funkwhale',
        categories: ['music', 'entertainment'],
        start_url: undefined,
        scope: undefined,
        short_name: 'Funkwhale',
        description: 'Your free and federated audio platform',
        icons: [
          {
            src: 'android-chrome-192x192.png',
            sizes: '192x192',
            type: 'image/png'
          },
          {
            src: 'android-chrome-512x512.png',
            sizes: '512x512',
            type: 'image/png'
          }
        ],
        prefer_related_applications: true,
        related_applications: [
          {
            platform: 'play',
            url: 'https://play.google.com/store/apps/details?id=audio.funkwhale.ffa',
            id: 'audio.funkwhale.ffa'
          },
          {
            platform: 'f-droid',
            url: 'https://f-droid.org/en/packages/audio.funkwhale.ffa/',
            id: 'audio.funkwhale.ffa'
          }
        ],
        shortcuts: [
          {
            name: 'Search',
            url: '/search',
            icons: []
          },
          {
            name: 'Library',
            url: '/library',
            icons: []
          },
          {
            name: 'Channels',
            url: '/subscriptions',
            icons: []
          }
        ]
      }
    })
  ],
  server: {
    port
  },
  resolve: {
    alias: {
      '?': resolve(__dirname, './test'),
      '~': resolve(__dirname, './src')
    }
  },
  test: {
    environment: 'jsdom',
    globals: true,
    coverage: {
      src: './src',
      all: true,
      reporter: ['text', 'cobertura']
    }
  }
}))
