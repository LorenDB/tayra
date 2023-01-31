import { defineConfig } from 'vite'
import Vue from '@vitejs/plugin-vue'
import VueI18n from '@intlify/unplugin-vue-i18n/vite'
import { VitePWA } from 'vite-plugin-pwa'
import { resolve } from 'path'

import manifest from './pwa-manifest.json'

const port = +(process.env.VUE_PORT ?? 8080)

// https://vitejs.dev/config/
export default defineConfig(({ mode }) => ({
  envPrefix: ['VUE_', 'FUNKWHALE_SENTRY_'],
  plugins: [
    // https://github.com/vitejs/vite/tree/main/packages/plugin-vue
    Vue(),

    // https://github.com/intlify/bundle-tools/tree/main/packages/vite-plugin-vue-i18n
    VueI18n({
      include: resolve(__dirname, './src/locales/**')
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
      manifest
    })
  ],
  server: {
    port
  },
  resolve: {
    alias: {
      '#': resolve(__dirname, './src/worker'),
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
