import { defineConfig } from 'vite'
import Sentry from 'sentry-vite-plugin'
import Vue from '@vitejs/plugin-vue'
import Inspector from 'vite-plugin-vue-inspector'
import { VitePWA } from 'vite-plugin-pwa'
import { resolve } from 'path'

const port = +(process.env.VUE_PORT ?? 8080)

// https://vitejs.dev/config/
export default defineConfig(({ mode }) => ({
  envPrefix: 'VUE_',
  plugins: [
    // https://github.com/huyanhai/sentry-vite-plugin
    Sentry({
      url: process.env.VUE_SENTRY_DSN?.split(/(\/|@)/)[6],
      include: './dist',
      ignore: ['node_modules', 'vite.config.js'],
      cleanSourceMap: false,
      dryRun: !process.env.VUE_SENTRY_DSN/*  || !!process.env.GITPOD_WORKSPACE_ID */,
      setCommits: {
        auto: true
      },
      deploy: {
        env: mode
      }
    }),

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
      }
    })
  ],
  server: {
    port
  },
  resolve: {
    alias: {
      '~': resolve(__dirname, './src')
    }
  },
  build: {
    rollupOptions: {
      input: {
        main: resolve(__dirname, './index.html'),
        embed: resolve(__dirname, './embed.html')
      }
    }
  }
}))
