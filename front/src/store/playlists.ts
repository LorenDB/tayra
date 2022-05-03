import axios from 'axios'
import { Module } from 'vuex'
import { RootState } from '~/store/index'

export interface State {
  playlists: any[]
  showModal: boolean
  modalTrack: null
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
    chooseTrack (state, value) {
      state.showModal = true
      state.modalTrack = value
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
      while (url != null) {
        const response = await axios.get(url, { params: { scope: 'me' } })
        playlists.push(...response.data.results)
        url = response.data.next
      }

      commit('playlists', playlists)
    }
  }
}

export default store
