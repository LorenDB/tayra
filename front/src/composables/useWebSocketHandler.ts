import type { WebSocketEvent } from '~/types'
import type { WebSocketEventName } from '~/store/ui'

import store from '~/store'
import { tryOnScopeDispose } from '@vueuse/core'

export default (eventName: WebSocketEventName, handler: (event: WebSocketEvent) => void) => {
  const id = `${+new Date() + Math.random()}`
  store.commit('ui/addWebsocketEventHandler', { eventName, handler, id })

  const stop = () => {
    store.commit('ui/removeWebsocketEventHandler', { eventName, id })
  }

  tryOnScopeDispose(stop)
  return stop
}
