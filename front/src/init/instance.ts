import type { NodeInfo } from '~/store/instance'
import type { InitModule } from '~/types'

import { whenever } from '@vueuse/core'

import useLogger from '~/composables/useLogger'

import axios from 'axios'

const logger = useLogger()

export const install: InitModule = async ({ store, router }) => {
  await store.dispatch('instance/fetchFrontSettings')

  const fetchNodeInfo = async () => {
    try {
      const [{ data }] = await Promise.all([
        axios.get<NodeInfo>('instance/nodeinfo/2.0/'),
        store.dispatch('instance/fetchSettings')
      ])

      if (data.metadata.library.music?.hours) {
        data.metadata.library.music.hours = Math.floor(data.metadata.library.music.hours)
      }

      store.commit('instance/nodeinfo', data)
    } catch (error) {
      logger.error('Error while fetching node info', error)
    }
  }

  whenever(() => store.state.instance.instanceUrl, fetchNodeInfo)

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

  return fetchNodeInfo()
}
