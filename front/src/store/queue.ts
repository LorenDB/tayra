import type { Module } from 'vuex'
import type { RootState } from '~/store/index'
import type { Track } from '~/types'

import { shuffle } from 'lodash-es'
import useLogger from '~/composables/useLogger'

export interface State {
  tracks: Track[]
  currentIndex: number
  ended: boolean
}

const logger = useLogger()

const store: Module<State, RootState> = {
  namespaced: true,
  state: {
    tracks: [],
    currentIndex: -1,
    ended: true
  },
  mutations: {
    reset (state) {
      state.tracks.length = 0
      state.currentIndex = -1
      state.ended = true
    },
    currentIndex (state, value) {
      state.currentIndex = value
    },
    ended (state, value) {
      state.ended = value
    },
    splice (state, { start, size }) {
      state.tracks.splice(start, size)
    },
    tracks (state, value) {
      state.tracks = value
    },
    insert (state, { track, index }) {
      state.tracks.splice(index, 0, track)
    },
    reorder (state, { tracks, oldIndex, newIndex }) {
      // called when the user uses drag / drop to reorder
      // tracks in queue
      state.tracks = tracks
      if (oldIndex === state.currentIndex) {
        state.currentIndex = newIndex
        return
      }
      if (oldIndex < state.currentIndex && newIndex >= state.currentIndex) {
        // item before was moved after
        state.currentIndex -= 1
      }
      if (oldIndex > state.currentIndex && newIndex <= state.currentIndex) {
        // item after was moved before
        state.currentIndex += 1
      }
    }
  },
  getters: {
    currentTrack: state => {
      return state.tracks[state.currentIndex]
    },
    hasNext: state => {
      return state.currentIndex < state.tracks.length - 1
    },
    hasPrevious: state => {
      return state.currentIndex > 0 && state.tracks.length > 1
    },
    isEmpty: state => state.tracks.length === 0
  },
  actions: {
    append ({ commit, state }, { track, index }) {
      index = index || state.tracks.length
      if (index > state.tracks.length - 1) {
        // we simply push to the end
        commit('insert', { track, index: state.tracks.length })
      } else {
        // we insert the track at given position
        commit('insert', { track, index })
      }
    },

    appendMany ({ state, dispatch }, { tracks, index, callback }) {
      logger.info('Appending many tracks to the queue', tracks.map((track: Track) => track.title))
      let shouldPlay = false

      if (state.tracks.length === 0) {
        index = 0
        shouldPlay = true
      } else {
        index = index ?? state.tracks.length
      }

      const total = tracks.length
      tracks.forEach((track: Track, i: number) => {
        const promise = dispatch('append', { track: track, index: index })
        index += 1

        if (callback && i + 1 === total) {
          promise.then(callback)
        }

        if (shouldPlay && promise && i + 1 === total) {
          promise.then(() => dispatch('next'))
        }
      })
    },

    cleanTrack ({ state, dispatch, commit }, index) {
      // are we removing current playin track
      const current = index === state.currentIndex

      if (current) {
        dispatch('player/stop', null, { root: true })
      }

      commit('splice', { start: index, size: 1 })
      if (index < state.currentIndex) {
        commit('currentIndex', state.currentIndex - 1)
      } else if (index > 0 && index === state.tracks.length && current) {
        // kind of a edge case: if you delete the last track of the queue
        // while it's playing we set current index to the previous one to
        // avoid the queue tab from being stuck because the player
        // disappeared cf #1092
        commit('currentIndex', state.tracks.length - 1)
      } else if (current) {
        // we play next track, which now have the same index
        commit('currentIndex', index)
      }

      if (state.currentIndex + 1 === state.tracks.length) {
        dispatch('radios/populateQueue', null, { root: true })
      }
    },

    previous ({ state, dispatch, rootState }) {
      if (state.currentIndex > 0 && rootState.player.currentTime < 3) {
        dispatch('currentIndex', state.currentIndex - 1)
      } else {
        dispatch('currentIndex', state.currentIndex)
      }
    },
    next ({ state, dispatch, commit, rootState }) {
      if (rootState.player.looping === 2 && state.currentIndex >= state.tracks.length - 1) {
        logger.info('Going back to the beginning of the queue')
        return dispatch('currentIndex', 0)
      } else {
        if (state.currentIndex < state.tracks.length - 1) {
          logger.debug('Playing next track')
          return dispatch('currentIndex', state.currentIndex + 1)
        } else {
          commit('ended', true)
        }
      }
    },
    last ({ state, dispatch }) {
      return dispatch('currentIndex', state.tracks.length - 1)
    },
    currentIndex ({ commit, state, rootState, dispatch }, index) {
      commit('ended', false)
      commit('player/currentTime', 0, { root: true })
      commit('currentIndex', index)

      if (state.tracks.length - index <= 2 && rootState.radios.running) {
        return dispatch('radios/populateQueue', null, { root: true })
      }
    },
    clean ({ dispatch, commit, state }) {
      dispatch('radios/stop', null, { root: true })
      dispatch('player/stop', null, { root: true })
      state.tracks.length = 0
      dispatch('currentIndex', -1)
      // so we replay automatically on next track append
      commit('ended', true)
    },
    async shuffle ({ dispatch, state }) {
      const shuffled = shuffle(state.tracks)
      state.tracks.length = 0

      await dispatch('appendMany', { tracks: shuffled })
      await dispatch('currentIndex', 0)
    }
  }
}

export default store
