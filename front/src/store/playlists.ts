import type { Module } from 'vuex'
import type { RootState } from '~/store/index'
import type { Playlist, Track } from '~/types'

import axios from 'axios'

export interface State {
  playlists: Playlist[]
  showModal: boolean
  modalTrack: null | Track
}

const store: Module<State, RootState> = {
  namespaced: true,
  state: {
    playlists: [],
    showModal: false,
    modalTrack: null
  },
  mutations: {
    playlists (state, value) {
      state.playlists = value
    },
    chooseTrack (state, value: Track | null) {
      if (value !== null) {
        state.showModal = true
        state.modalTrack = value
      }
    },
    showModal (state, value) {
      state.showModal = value
    },
    reset (state) {
      state.playlists = []
      state.modalTrack = null
      state.showModal = false
    }
  },
  actions: {
    async fetchOwn ({ commit, rootState }) {
      const userId = rootState.auth.profile?.id
      if (!userId) return

      const playlists = []
      let url = 'playlists/'
      while (url !== null) {
        const response = await axios.get(url, { params: { scope: 'me' } })
        playlists.push(...response.data.results)
        url = response.data.next
      }

      commit('playlists', playlists)
    }
  }
}

export default store
