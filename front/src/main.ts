import type { InitModule, InitModuleContext } from '~/types'

import store, { key } from '~/store'
import router from '~/router'

import { createApp, defineAsyncComponent, h } from 'vue'

import useLogger from '~/composables/useLogger'
import useTheme from '~/composables/useTheme'

import '~/api'

// NOTE: Set the theme as fast as possible
useTheme()

const logger = useLogger()
logger.info('Loading environment:', import.meta.env.MODE)
logger.debug('Environment variables:', import.meta.env)

const app = createApp({
  name: 'Root',
  data: () => ({ ready: false }),
  mounted () {
    this.ready = true
    logger.info('Everything loaded!')
  },
  render () {
    if (this.ready) {
      return h(defineAsyncComponent(() => import('~/App.vue')))
    }

    return null
  }
})

app.use(router)
app.use(store, key)

const modules: Record<string | 'axios', { install?: InitModule }> = import.meta.glob('./init/*.ts', { eager: true })
const moduleContext: InitModuleContext = {
  app,
  router,
  store
}

// NOTE: Other modules may depend on network requests and we need to ensure
//       that all axios interceptors are set before any requests are made
//       and that the instance url is set before any requests are made
const IMPORTANT_MODULES_QUEUE = ['axios', 'instance']
const waitForImportantModules = async () => {
  for (const moduleName of IMPORTANT_MODULES_QUEUE) {
    const path = `./init/${moduleName}.ts`
    if (!(path in modules)) {
      logger.error(`Failed to load important module: ${path}`)
      continue
    }

    await modules[path].install?.(moduleContext)
    delete modules[path]
  }
}

waitForImportantModules()
  // NOTE: We load the modules in parallel
  .then(() => Promise.all(Object.values(modules).map(module => module.install?.(moduleContext))))
  .catch(error => logger.error('Failed to load modules:', error))
  // NOTE: We need to mount the app after all modules are loaded
  .finally(() => app.mount('#app'))

// TODO (wvffle): Rename filters from useSharedLabels to filters from backend
