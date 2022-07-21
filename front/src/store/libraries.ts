import type { Module } from 'vuex'
import type { RootState } from '~/store/index'

import axios from 'axios'
import useLogger from '~/composables/useLogger'

export interface State {
  followsByLibrary: {
    [key: string]: Library
  }
  count: number
}

interface Library {
  uuid: string
}

const logger = useLogger()

const store: Module<State, RootState> = {
  namespaced: true,
  state: {
    followsByLibrary: {},
    count: 0
  },
  mutations: {
    follows: (state, { library, follow }) => {
      if (follow) {
        state.followsByLibrary[library] = follow
      } else {
        delete state.followsByLibrary[library]
      }

      state.count = Object.keys(state.followsByLibrary).length
    },
    reset (state) {
      state.followsByLibrary = {}
      state.count = 0
    }
  },
  getters: {
    follow: (state) => (library: string) => {
      return state.followsByLibrary[library]
    }
  },
  actions: {
    set ({ commit, state }, { uuid, value }) {
      if (value) {
        return axios.post('federation/follows/library/', { target: uuid }).then((response) => {
          logger.info('Successfully subscribed to library')
          commit('follows', { library: uuid, follow: response.data })
        }, () => {
          logger.info('Error while subscribing to library')
          commit('follows', { library: uuid, follow: null })
        })
      } else {
        const follow = state.followsByLibrary[uuid]
        return axios.delete(`federation/follows/library/${follow.uuid}/`).then(() => {
          logger.info('Successfully unsubscribed from library')
          commit('follows', { library: uuid, follow: null })
        }, () => {
          logger.info('Error while unsubscribing from library')
          commit('follows', { library: uuid, follow })
        })
      }
    },
    toggle ({ getters, dispatch }, uuid) {
      dispatch('set', { uuid, value: !getters.follow(uuid) })
    },
    fetchFollows ({ dispatch, state, commit, rootState }, url) {
      const promise = axios.get('federation/follows/library/all/')
      return promise.then((response) => {
        response.data.results.forEach((result: { library: string }) => {
          commit('follows', { library: result.library, follow: result })
        })
      })
    }
  }
}

export default store
