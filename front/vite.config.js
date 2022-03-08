// vite.config.js

import { defineConfig } from 'vite'
import { createVuePlugin as vue } from "vite-plugin-vue2";

import path from 'path'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [
    vue(),
    {
      name: 'fix-fomantic-ui-css',
      transform (src, id) {
        if (id.includes('fomantic-ui-css') && id.endsWith('.min.js')) {
          return `import jQuery from 'jquery';${src}`
        }
      }
    },
    {
      name: 'fix-django-channels',
      transform (src, id) {
        if (id.includes('django-channels')) {
          return `var parcelRequire;${src}`
        }
      }
    }
  ],
  server: {
    port: process.env.VUE_PORT || '8080',
    hmr: {
      port: '8000',
      protocol: 'ws',
    }
  },  
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },  
})
