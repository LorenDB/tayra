import type { Module } from 'vuex'
import type { RootState } from '~/store/index'

import axios from 'axios'
import useLogger from '~/composables/useLogger'

export interface State {
  tracks: string[]
  count: number
}

const logger = useLogger()

const store: Module<State, RootState> = {
  namespaced: true,
  state: {
    tracks: [],
    count: 0
  },
  mutations: {
    track: (state, { id, value }) => {
      if (value) {
        if (!state.tracks.includes(id)) {
          state.tracks.push(id)
        }
      } else {
        const index = state.tracks.indexOf(id)
        if (index > -1) {
          state.tracks.splice(index, 1)
        }
      }

      state.count = state.tracks.length
    },
    reset (state) {
      state.tracks.length = 0
      state.count = 0
    }
  },
  getters: {
    isFavorite: (state) => (id: string) => {
      return state.tracks.includes(id)
    }
  },
  actions: {
    set ({ commit }, { id, value }) {
      commit('track', { id, value })
      if (value) {
        return axios.post('favorites/tracks/', { track: id }).then(() => {
          logger.info('Successfully added track to favorites')
        }, () => {
          logger.info('Error while adding track to favorites')
          commit('track', { id, value: !value })
        })
      } else {
        return axios.post('favorites/tracks/remove/', { track: id }).then(() => {
          logger.info('Successfully removed track from favorites')
        }, () => {
          logger.info('Error while removing track from favorites')
          commit('track', { id, value: !value })
        })
      }
    },
    toggle ({ getters, dispatch }, id) {
      dispatch('set', { id, value: !getters.isFavorite(id) })
    },
    async fetch ({ commit, rootState }) {
      // will fetch favorites by batches from API to have them locally
      const params = {
        user: rootState.auth.profile?.id,
        page_size: 50,
        ordering: '-creation_date'
      }

      const response = await axios.get('favorites/tracks/all/', { params })
      logger.info('Fetched a batch of ' + response.data.results.length + ' favorites')

      for (const result of response.data.results) {
        commit('track', { id: result.track, value: true })
      }
    }
  }
}

export default store
