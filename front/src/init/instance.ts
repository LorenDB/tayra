import type { InitModule } from '~/types'

import { watch } from 'vue'
import axios from 'axios'

export const install: InitModule = async ({ store, router }) => {
  await store.dispatch('instance/fetchFrontSettings')
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
    router.replace(url)
    return
  }

  if (!store.state.instance.instanceUrl) {
    const defaultInstanceUrl = store.state.instance.frontSettings.defaultServerUrl
    store.commit('instance/instanceUrl', defaultInstanceUrl)
  } else {
    // NOTE: Needed to trigger initialization of axios / service worker / web socket
    // TODO (wvffle): Check if it is really needed
    store.commit('instance/instanceUrl', store.state.instance.instanceUrl)
  }
}
