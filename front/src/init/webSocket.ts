import { InitModule } from '~/types'
import { watchEffect, watch } from '@vue/composition-api'
import { useWebSocket, whenever } from '@vueuse/core'

export const install: InitModule = ({ store }) => {
  watch(() => store.state.instance.instanceUrl, () => {
    const url = store.getters['instance/absoluteUrl']('api/v1/activity')
      .replace(/^http/, 'ws')

    const { data, status, open, close } = useWebSocket(url, {
      autoReconnect: true,
      immediate: false
    })

    watch(() => store.state.auth.authenticated, (authenticated) => {
      if (authenticated) return open()
      close()
    })

    whenever(data, () => {
      return store.dispatch('ui/websocketEvent', JSON.parse(data.value))
    })

    watchEffect(() => {
      console.log('Websocket status:', status.value)
    })
  })
}
