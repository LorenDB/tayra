import router from '~/router'
import store from '~/store'
import { createApp } from 'vue'
import useLogger from '~/composables/useLogger'
import useTheme from '~/composables/useTheme'
useTheme()

const logger = useLogger()
logger.info('Loading environment:', import.meta.env.MODE)
logger.debug('Environment variables:', import.meta.env)

const app = createApp({
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

app.use(router)
app.use(store)

const modules: Promise<unknown>[] = []
for (const module of Object.values(import.meta.globEager('./init/*.ts'))) {
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
