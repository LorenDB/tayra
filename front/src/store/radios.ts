import type { Dispatch, Module } from 'vuex'
import type { RootState } from '~/store/index'

import axios from 'axios'
import { CLIENT_RADIOS } from '~/utils/clientRadios'
import useLogger from '~/composables/useLogger'

export interface State {
  current: null | CurrentRadio
  running: boolean
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

export type RadioConfig = { type: 'tag', names: string[] } | { type: 'artist', ids: string[] }

export interface PopulateQueuePayload {
  current: CurrentRadio
  playNow: boolean
  dispatch: Dispatch
}

const logger = useLogger()

const store: Module<State, RootState> = {
  namespaced: true,
  state: {
    current: null,
    running: false
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
        favorites: {
          name: 'Favorites',
          description: 'Play your favorites tunes in a never-ending happiness loop.'
        },
        'less-listened': {
          name: 'Less listened',
          description: "Listen to tracks you usually don't. It's time to restore some balance."
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
    async populateQueue ({ commit, rootState, state, dispatch }, playNow) {
      if (!state.running) {
        return
      }

      if (rootState.player.errorCount >= rootState.player.maxConsecutiveErrors - 1) {
        return
      }

      const params = { session: state.current?.session }

      if (state.current?.clientOnly) {
        return CLIENT_RADIOS[state.current.type].populateQueue({ current: state.current, dispatch, playNow })
      }

      try {
        const response = await axios.post('radios/tracks/', params)

        logger.info('Adding track to queue from radio')
        await dispatch('queue/append', { track: response.data.track }, { root: true })

        if (playNow) {
          await dispatch('queue/last', null, { root: true })
          await dispatch('player/resumePlayback', null, { root: true })
        }
      } catch (error) {
        logger.error('Error while adding track to queue from radio', error)
        commit('reset')
      }
    }
  }
}

export default store
