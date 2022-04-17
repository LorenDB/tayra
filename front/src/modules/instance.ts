import { AppModule } from '@/types'
import { watch } from '@vue/composition-api'
import axios from 'axios'

export const install: AppModule = async ({ store, router }) => {
  watch(() => store.state.instance.instanceUrl, async () => {
    const [{ data }] = await Promise.all([
      axios.get('instance/nodeinfo/2.0/'),
      store.dispatch('instance/fetchSettings')
    ])

    store.commit('instance/nodeinfo', data)
  })

  const urlParams = new URLSearchParams(window.location.search)
  const serverUrl = urlParams.get('_server')
  if (serverUrl) {
    store.commit('instance/instanceUrl', serverUrl)
  }

  const url = urlParams.get('_url')
  if (url) {
    return router.replace(url)
  }

  if (!store.state.instance.instanceUrl) {
    // We have several way to guess the API server url. By order of precedence:
    // 1. use the url provided in settings.json, if any
    // 2. use the url specified when building via VUE_APP_INSTANCE_URL
    // 3. use the current url
    const defaultInstanceUrl = store.state.instance.frontSettings.defaultServerUrl ||
      import.meta.env.VUE_APP_INSTANCE_URL ||
      store.getters['instance/defaultUrl']()

    store.commit('instance/instanceUrl', defaultInstanceUrl)
  } else {
    // needed to trigger initialization of axios / service worker / web socket
    store.commit('instance/instanceUrl', store.state.instance.instanceUrl)
  }
}
