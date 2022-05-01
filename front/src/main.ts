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

// TODO (wvffle): Migrate to pinia
// TODO (wvffle): Remove global Vue (Only vuex files affected)
// TODO (wvffle): Remove shims-vue2.d.ts
// TODO (wvffle): Check for mixin merging: https://v3-migration.vuejs.org/breaking-changes/data-option.html#mixin-merge-behavior-change=
// TODO (wvffle): Use emits options: https://v3-migration.vuejs.org/breaking-changes/emits-option.html
// TODO (wvffle): Migrate to new v-model: https://v3-migration.vuejs.org/breaking-changes/v-model.html
// TODO (wvffle): Migrate to <script setup>
