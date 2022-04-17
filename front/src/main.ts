import logger from '~/logging'
import App from '~/App.vue'
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
  render: (h: CreateElement) => h(App)
})

app.use(VueCompositionAPI)
app.use(VueLazyload)

for (const module of Object.values(import.meta.globEager('./modules/*.ts'))) {
  module.install?.({
    app,
    router,
    store
  })
}

store.dispatch('instance/fetchFrontSettings').finally(() => {
  app.mount('#app')
  logger.default.info('Everything loaded!')
})
