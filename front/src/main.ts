import logger from '~/logging'
import router from '~/router'
import VueLazyload from 'vue-lazyload'
import store from '~/store'
import { sync } from 'vuex-router-sync'
import VueCompositionAPI, { createApp } from '@vue/composition-api'
import { CreateElement } from 'vue'

logger.default.info('Loading environment:', import.meta.env.MODE)
logger.default.debug('Environment variables:', import.meta.env)

sync(store, router)

const app = createApp({
  store,
  router,
  data: () => ({ isMounted: false }),
  async mounted () {
    this.isMounted = true
  },
  render (h: CreateElement) {
    if (this.isMounted) {
      return import('~/App.vue')
    }

    // TODO (wvffle): Import fake app component
    return h()
  }
})

app.use(VueCompositionAPI)
app.use(VueLazyload)

const modules: Promise<unknown>[] = []
for (const module of Object.values(import.meta.globEager('./modules/*.ts'))) {
  modules.push(module.install?.({
    app,
    router,
    store
  }))
}

store.dispatch('instance/fetchFrontSettings').finally(async () => {
  // Wait for all modules to load
  await Promise.all(modules)

  app.mount('#app')
  logger.default.info('Everything loaded!')
})
