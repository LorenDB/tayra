import axios from 'axios'
import useLogger from '~/composables/useLogger'
import { ListenWSEvent } from '~/types'
import { RootState } from '~/store'
import { Store } from 'vuex'
import { CurrentRadio, PopulateQueuePayload } from '~/store/radios'

const logger = useLogger()

export const CLIENT_RADIOS = {
  // some radios are client side only, so we have to implement the populateQueue
  // method by hand
  account: {
    offset: 1,
    populateQueue ({ current, dispatch, playNow }: PopulateQueuePayload) {
      const params = { scope: `actor:${current.objectId.fullUsername}`, ordering: '-creation_date', page_size: 1, page: this.offset }
      axios.get('history/listenings', { params }).then(async (response) => {
        const latest = response.data.results[0]
        if (!latest) {
          logger.error('No more tracks')
          await dispatch('stop')
        }

        this.offset += 1
        const append = dispatch('queue/append', { track: latest.track }, { root: true })
        if (playNow) {
          append.then(() => dispatch('queue/last', null, { root: true }))
        }
      }, async (error) => {
        logger.error('Error while fetching listenings', error)
        await dispatch('stop')
      })
    },
    stop () {
      this.offset = 1
    },
    handleListen (current: CurrentRadio, event: ListenWSEvent, store: Store<RootState>) {
      // TODO: handle actors from other pods
      if (event.actor.local_id === current.objectId.username) {
        axios.get(`tracks/${event.object.local_id}`).then(async (response) => {
          if (response.data.uploads.length > 0) {
            await store.dispatch('queue/append', { track: response.data })
            this.offset += 1
          }
        }, (error) => {
          logger.error('Cannot retrieve track info', error)
        })
      }
    }
  }
}
