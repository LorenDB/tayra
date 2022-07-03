import {
  InitModule,
  ListenWSEvent,
  PendingReviewEditsWSEvent,
  PendingReviewReportsWSEvent,
  PendingReviewRequestsWSEvent,
} from '~/types'
import { watchEffect, watch } from 'vue'
import { useWebSocket, whenever } from '@vueuse/core'
import useWebSocketHandler from '~/composables/useWebSocketHandler'
import { CLIENT_RADIOS } from '~/utils/clientRadios'

export const install: InitModule = ({ store }) => {
  watch(() => store.state.instance.instanceUrl, () => {
    const url = store.getters['instance/absoluteUrl']('api/v1/activity')
      .replace(/^http/, 'ws')

    const { data, status, open, close } = useWebSocket(url, {
      autoReconnect: import.meta.env.DEV ? { retries: 3 } : true,
      immediate: false
    })

    watch(() => store.state.auth.authenticated, (authenticated) => {
      if (authenticated) return open()
      close()
    }, { immediate: true })

    whenever(data, () => {
      return store.dispatch('ui/websocketEvent', JSON.parse(data.value))
    })

    watchEffect(() => {
      console.log('Websocket status:', status.value)
    })
  }, { immediate: true })

  // WebSocket handlers
  useWebSocketHandler('inbox.item_added', () => {
    store.commit('ui/incrementNotifications', { type: 'inbox', count: 1 })
  })

  useWebSocketHandler('mutation.created', (event) => {
    store.commit('ui/incrementNotifications', {
      type: 'pendingReviewEdits',
      value: (event as PendingReviewEditsWSEvent).pending_review_count
    })
  })

  useWebSocketHandler('mutation.updated', (event) => {
    store.commit('ui/incrementNotifications', {
      type: 'pendingReviewEdits',
      value: (event as PendingReviewEditsWSEvent).pending_review_count
    })
  })

  useWebSocketHandler('report.created', (event) => {
    store.commit('ui/incrementNotifications', {
      type: 'pendingReviewReports',
      value: (event as PendingReviewReportsWSEvent).unresolved_count
    })
  })

  useWebSocketHandler('user_request.created', (event) => {
    store.commit('ui/incrementNotifications', {
      type: 'pendingReviewRequests',
      value: (event as PendingReviewRequestsWSEvent).pending_count
    })
  })

  useWebSocketHandler('Listen', (event) => {
    if (store.state.radios.current && store.state.radios.running) {
      const { current } = store.state.radios

      if (current.clientOnly) {
        CLIENT_RADIOS[current.type].handleListen(current, event as ListenWSEvent, store)
      }
    }
  })
}
