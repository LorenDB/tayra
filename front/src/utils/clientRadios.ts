import type { ListenWS } from '~/composables/useWebSocketHandler'
import type { CurrentRadio } from '~/store/radios'
import type { Track } from '~/types'

import { useQueue } from '~/composables/audio/queue'

import axios from 'axios'

import useLogger from '~/composables/useLogger'

const logger = useLogger()

export const CLIENT_RADIOS = {
  // some radios are client side only, so we have to implement the populateQueue
  // method by hand
  account: {
    offset: 1,
    async fetchNextTrack (current: CurrentRadio) {
      const params = {
        scope: `actor:${current.objectId?.fullUsername}`,
        ordering: '-creation_date',
        page_size: 1,
        page: this.offset
      }

      // NOTE: This is unhandled as we want to pass the exception further down
      const response = await axios.get('history/listenings', { params })

      const latest = response.data.results[0]
      if (!latest) {
        logger.error('No more tracks')
        return undefined
      }

      this.offset += 1
      return latest.track as Track
    },

    stop () {
      this.offset = 1
    },

    async handleListen (current: CurrentRadio, event: ListenWS) {
      // TODO: handle actors from other pods
      if (event.actor.local_id === current.objectId?.username) {
        try {
          const response = await axios.get(`tracks/${event.object.local_id}`)

          if (response.data.uploads.length > 0) {
            const { enqueue } = useQueue()
            await enqueue(response.data as Track)
            this.offset += 1
          }
        } catch (error) {
          logger.error('Cannot retrieve track info', error)
        }
      }
    }
  }
}
