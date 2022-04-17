import { defineConfig, HmrOptions } from 'vite'
import { createVuePlugin as Vue2 } from 'vite-plugin-vue2'
import ScriptSetup from 'unplugin-vue2-script-setup/vite'

// @ts-ignore
import path from 'path'

const port = +(process.env.VUE_PORT ?? 8080)

const hmr = {
  port: process.env.HMR_PORT || (process.env.FUNKWHALE_PROTOCOL === 'https' ? 443 : port),
  protocol: process.env.HMR_PROTOCOL || (process.env.FUNKWHALE_PROTOCOL === 'https' ? 'wss' : 'ws')
} as HmrOptions

if (process.env.GITPOD_WORKSPACE_URL) {
  hmr.host = process.env.GITPOD_WORKSPACE_URL.replace('https://', `${process.env.HMR_PORT ?? process.env.VUE_PORT ?? 4000}-`)
  hmr.clientPort = 443
  hmr.protocol = 'wss'
  delete hmr.port
}

// https://vitejs.dev/config/
export default defineConfig(() => ({
  envPrefix: 'VUE_',
  plugins: [
    // https://github.com/underfin/vite-plugin-vue2
    Vue2(),

    // https://github.com/antfu/unplugin-vue2-script-setup
    ScriptSetup(),

    {
      name: 'fix-fomantic-ui-css',
      transform (src, id) {
        if (id.includes('fomantic-ui-css') && id.endsWith('.min.js')) {
          return `import jQuery from 'jquery';${src}`
        }
      }
    }
  ],
  server: { port, hmr },
  resolve: {
    alias: {
      '~': path.resolve(__dirname, './src'),

      // TODO (wvffle): Remove @/dependency from all files as `@` is used as an organization prefix
      '@': path.resolve(__dirname, './src')
    }
  },
  build: {
    rollupOptions: {
      input: {
        main: path.resolve(__dirname, './index.html'),
        embed: path.resolve(__dirname, './embed.html')
      }
    }
  }
}))
