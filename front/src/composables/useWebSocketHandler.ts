import type { Notification } from '~/types'

import store from '~/store'
import { tryOnScopeDispose } from '@vueuse/core'

export interface ImportStatusWS {
  old_status: 'pending' | 'skipped' | 'finished' | 'errored'
  new_status: 'pending' | 'skipped' | 'finished' | 'errored'
  upload: {
    import_reference: string
    uuid: string
  }
}

export interface ListenWsEventObject {
  local_id: string
}

export interface ListenWS {
  actor: ListenWsEventObject
  object: ListenWsEventObject
}

// TODO (wvffle): Add reactivity to recently listened / favorited / added (#1316, #1534)
// export interface ListenWSEvent extends Listening {
//   type: 'Listen'
// }

export interface PendingReviewEdits {
  pending_review_count: number
}

export interface PendingReviewReports {
  unresolved_count: number
}

export interface PendingReviewRequests {
  pending_count: number
}

export interface InboxItemAdded {
  item: Notification
}

type stopFn = () => void

function useWebSocketHandler (eventName: 'inbox.item_added', handler: (event: InboxItemAdded) => void): stopFn
function useWebSocketHandler (eventName: 'report.created', handler: (event: PendingReviewReports) => void): stopFn
function useWebSocketHandler (eventName: 'mutation.created', handler: (event: PendingReviewEdits) => void): stopFn
function useWebSocketHandler (eventName: 'mutation.updated', handler: (event: PendingReviewEdits) => void): stopFn
function useWebSocketHandler (eventName: 'import.status_updated', handler: (event: ImportStatusWS) => void): stopFn
function useWebSocketHandler (eventName: 'user_request.created', handler: (event: PendingReviewRequests) => void): stopFn
function useWebSocketHandler (eventName: 'Listen', handler: (event: ListenWS) => void): stopFn

function useWebSocketHandler (eventName: string, handler: (event: any) => void): stopFn {
  const id = `${+new Date() + Math.random()}`
  store.commit('ui/addWebsocketEventHandler', { eventName, handler, id })

  const stop = () => {
    store.commit('ui/removeWebsocketEventHandler', { eventName, id })
  }

  tryOnScopeDispose(stop)
  return stop
}

export default useWebSocketHandler
