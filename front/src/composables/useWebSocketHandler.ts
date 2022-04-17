import store from '~/store'
import { tryOnScopeDispose } from '@vueuse/core'
import { WebSocketEvent } from '~/types'

export default (eventName: string, handler: (event: WebSocketEvent) => void) => {
  const id = `${+new Date() + Math.random()}`
  store.commit('ui/addWebsocketEventHandler', { eventName, handler, id })

  const stop = () => {
    store.commit('ui/removeWebsocketEventHandler', { eventName, id })
  }

  tryOnScopeDispose(stop)
  return stop
}
