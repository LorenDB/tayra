import logger from '~/logging'
import router from '~/router'
import VueLazyload from 'vue-lazyload'
import store from '~/store'
import { sync } from 'vuex-router-sync'
import Vue, { createApp } from 'vue'
import useTheme from '~/composables/useTheme'
useTheme()

Vue.config.devtools = true

logger.default.info('Loading environment:', import.meta.env.MODE)
logger.default.debug('Environment variables:', import.meta.env)

sync(store, router)

const app = createApp({
  store,
  router,
  components: {
    App: () => import('~/App.vue')
  },
  data: () => ({ isMounted: false }),
  async mounted () {
    this.isMounted = true
  },
  render (h) {
    if (this.isMounted) {
      return h('app')
    }

    // TODO (wvffle): Import fake app component
    return h()
  }
})

app.use(VueLazyload)

const modules: Promise<unknown>[] = []
for (const module of Object.values(import.meta.globEager('./init/*.ts'))) {
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
