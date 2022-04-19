import router from '~/router'
import store from '~/store'
import { configureCompat, createApp, defineAsyncComponent, h } from 'vue'
import useLogger from '~/composables/useLogger'
import useTheme from '~/composables/useTheme'
useTheme()

configureCompat({
  RENDER_FUNCTION: false
})

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
