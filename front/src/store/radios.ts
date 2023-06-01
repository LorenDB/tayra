import type { BackendError, Track } from '~/types'
import type { RootState } from '~/store/index'
import type { Module } from 'vuex'

import { useQueue } from '~/composables/audio/queue'
import { usePlayer } from '~/composables/audio/player'
import { CLIENT_RADIOS } from '~/utils/clientRadios'

import axios from 'axios'

import useLogger from '~/composables/useLogger'

export interface State {
  current: null | CurrentRadio
  running: boolean
  populating: boolean
  retries: number
}

export interface ObjectId {
  username: string
  fullUsername: string
}

export interface CurrentRadio {
  clientOnly: boolean
  session: null
  type: 'account'
  customRadioId: number
  config: RadioConfig
  objectId: ObjectId | null
}

export type RadioConfig = { type: 'tag', names: string[] } | { type: 'artist' | 'playlist', ids: string[] }

const logger = useLogger()

const store: Module<State, RootState> = {
  namespaced: true,
  state: {
    current: null,
    running: false,
    populating: false,
    retries: 0
  },
  getters: {
    types: () => {
      return {
        'actor-content': {
          name: 'Your content',
          description: 'Picks from your own libraries'
        },
        random: {
          name: 'Random',
          description: "Totally random picks, maybe you'll discover new things?"
        },
        random_library: {
          name: 'Random',
          description: 'Play something random from your library. Maybe you\'ll surprise yourself!'
        },
        favorites: {
          name: 'Favorites',
          description: 'Play your favorites tunes in a never-ending happiness loop.'
        },
        'less-listened': {
          name: 'Less listened',
          description: "Listen to tracks you usually don't. It's time to restore some balance."
        },
        'less-listened_library': {
          name: 'Less listened',
          description: "Listen to tracks from your library you usually don't. It's time to restore some balance."
        },
        'recently-added': {
          name: 'Recently Added',
          description: 'Newest content on the network. Get some fresh air.'
        }
      }
    }
  },
  mutations: {
    reset (state) {
      state.running = false
      state.current = null
      state.populating = false
      state.retries = 0
    },
    current: (state, value) => {
      state.current = value
    },
    running: (state, value) => {
      state.running = value
    }
  },
  actions: {
    start ({ commit, dispatch }, { type, objectId, customRadioId, clientOnly, config }) {
      const params = {
        radio_type: type,
        related_object_id: objectId,
        custom_radio: customRadioId,
        config
      }

      if (clientOnly) {
        commit('current', { type, objectId, customRadioId, clientOnly, config })
        commit('running', true)
        dispatch('populateQueue', true)
        return
      }

      return axios.post('radios/sessions/', params).then((response) => {
        logger.info('Successfully started radio ', type)
        commit('current', { type, objectId, session: response.data.id, customRadioId })
        commit('running', true)
        dispatch('populateQueue', true)
      }, () => {
        logger.error('Error while starting radio', type)
      })
    },
    stop ({ commit, state }) {
      if (state.current?.clientOnly) {
        CLIENT_RADIOS[state.current.type].stop()
      }

      commit('current', null)
      commit('running', false)
    },
    async populateQueue ({ commit, dispatch, state }, playNow) {
      if (!state.running || state.populating) {
        return
      }

      state.populating = true

      const { enqueue, playTrack, tracks } = useQueue()
      const { isPlaying, pauseReason, PauseReason } = usePlayer()

      const params = { session: state.current?.session }

      try {
        logger.info('Adding track to queue from radio')

        const track = state.current?.clientOnly
          ? await CLIENT_RADIOS[state.current.type].fetchNextTrack(state.current)
          : await axios.post('radios/tracks/', params).then(response => response.data.track as Track)

        state.retries = 0

        if (track === undefined) {
          isPlaying.value = false
          pauseReason.value = PauseReason.EndOfRadio
          return
        }

        await enqueue(track)

        if (isPlaying.value === false && pauseReason.value === PauseReason.EndOfQueue) {
          playNow = true
        }

        if (playNow) {
          await playTrack(tracks.value.length - 1)
          isPlaying.value = true
        }
      } catch (error) {
        if ((error as BackendError).backendErrors?.[0] === 'Radio doesn\'t have more candidates') {
          commit('ui/addMessage', {
            content: (error as BackendError).backendErrors?.[0]
          }, { root: true })
        } else {
          logger.error('Error while adding track to queue from radio', error)
          if (state.retries++ < 5) {
            logger.info(`Retrying (${state.retries})...`)
            return dispatch('populateQueue', playNow)
          }
        }

        logger.info('Resetting radio queue due to error or lack of new candidates')
        commit('reset')
      } finally {
        state.populating = false
      }
    }
  }
}

export default store
