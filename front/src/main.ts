import router from '~/router'
import store, { key } from '~/store'
// @ts-expect-error typescript does not know about configureCompat
import { configureCompat, createApp, defineAsyncComponent, h } from 'vue'
import useLogger from '~/composables/useLogger'
import useTheme from '~/composables/useTheme'

// NOTE: Set the theme as fast as possible
useTheme()

configureCompat({
  RENDER_FUNCTION: false,
  COMPONENT_V_MODEL: false,
  // TODO (wvffle): Make sure it works
  //                Search pattern: v-for([^>]|\n)+?[^h]ref
  V_FOR_REF: false,
  OPTIONS_BEFORE_DESTROY: false,
  OPTIONS_DESTROYED: false,
  CUSTOM_DIR: false,
  INSTANCE_EVENT_HOOKS: false,
  INSTANCE_LISTENERS: false,
  INSTANCE_EVENT_EMITTER: false,
  INSTANCE_CHILDREN: false,
  GLOBAL_SET: false,
  GLOBAL_DELETE: false,
  INSTANCE_SET: false,
  INSTANCE_DELETE: false,
  COMPILER_V_BIND_SYNC: false,
  COMPILER_V_ON_NATIVE: false,
  FILTERS: false
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
app.use(store, key)

const modules: Array<Promise<unknown>> = []
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

// TODO (wvffle): Rename filters from useSharedLabels to filters from backend
// TODO (wvffle): Check for mixin merging: https://v3-migration.vuejs.org/breaking-changes/data-option.html#mixin-merge-behavior-change=
// TODO (wvffle): Use emits options: https://v3-migration.vuejs.org/breaking-changes/emits-option.html
// TODO (wvffle): Find all array watchers and make them deep
// TODO (wvffle): Migrate to <script setup lang="ts"> and remove allowJs from tsconfig.json
// TODO (wvffle): Replace `from '(../)+` with `from '~/`
// TODO (wvffle): Fix props not being available in template in IntelliJ Idea
// TODO (wvffle): Use navigation guards
