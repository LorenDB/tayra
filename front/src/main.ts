import type { InitModule } from '~/types'

import store, { key } from '~/store'
import router from '~/router'
import devtools from '@vue/devtools'

import { createApp, defineAsyncComponent, h } from 'vue'

import useLogger from '~/composables/useLogger'
import useTheme from '~/composables/useTheme'

import '~/api'

// NOTE: Set the theme as fast as possible
useTheme()

if (import.meta.env.MODE === 'development') {
  devtools.connect(/* host, port */)
}

const logger = useLogger()
logger.info('Loading environment:', import.meta.env.MODE)
logger.debug('Environment variables:', import.meta.env)

const app = createApp({
  name: 'Root',
  data: () => ({ ready: false }),
  mounted () {
    this.ready = true
  },
  render () {
    if (this.ready) {
      return h(defineAsyncComponent(() => import('~/App.vue')))
    }

    return null
  }
})

app.config.performance = false

app.use(router)
app.use(store, key)

const modules: Array<void | Promise<void>> = []
for (const module of Object.values(import.meta.glob('./init/*.ts', { eager: true })) as { install?: InitModule }[]) {
  modules.push(module.install?.({
    app,
    router,
    store
  }))
}

// Wait for all modules to load
Promise.all(modules).finally(() => {
  app.mount('#app')
  logger.info('Everything loaded!')
})

// TODO (wvffle): Rename filters from useSharedLabels to filters from backend
