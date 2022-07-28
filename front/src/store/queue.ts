import type { Module } from 'vuex'
import type { RootState } from '~/store/index'
import type { Track } from '~/types'

import { shuffle, chunk } from 'lodash-es'
import useLogger from '~/composables/useLogger'

const CHUNK_SIZE = 50

export interface State {
  tracks: Track[]
  unshuffled: Track[]
  // NOTE: It's null when we are rehydrated from local storage
  //       and we were mid-shuffling before
  shuffleAbortController?: AbortController | null
  currentIndex: number
}

const logger = useLogger()

// Load useWebAudioPlayer dynamically to avoid vuex not initialized issues
const useWebAudioPlayer = async () => {
  const { default: useWebAudioPlayer } = await import('~/composables/audio/useWebAudioPlayer')
  return useWebAudioPlayer()
}

interface DeferredAppendOptions {
  signal?: AbortSignal
  mapChunk?: (chunk: Track[]) => Track[]
  mapChunks?: (chunk: Track[][]) => Track[][]
  afterChunk?: (i: number, chunk: Track[]) => Promise<void> | void
}

const deferredAppend = async (from: Track[], to: Track[], options: DeferredAppendOptions = {}) => {
  const {
    mapChunk = (i) => i,
    mapChunks = (i) => i,
    afterChunk = () => {}
  } = options

  const chunks = mapChunks(chunk(from, CHUNK_SIZE))

  const firstChunk = mapChunk(chunks[0])
  if (!firstChunk) return

  to.push(...firstChunk)
  await afterChunk(0, firstChunk)

  for (let i = 1; i < chunks.length; i++) {
    // Break if we have aborted
    if (options.signal?.aborted) {
      break
    }

    const chunk = mapChunk(chunks[i])
    await new Promise<void>(resolve => {
      requestAnimationFrame(async () => {
        // Break before modyfing the array, if we have aborted
        if (options.signal?.aborted) {
          return resolve()
        }

        to.push(...chunk)
        await afterChunk(0, chunk)
        return resolve()
      })
    })
  }
}

const store: Module<State, RootState> = {
  namespaced: true,
  state: {
    tracks: [],
    unshuffled: [],
    currentIndex: -1
  },
  mutations: {
    reset (state) {
      state.tracks.length = 0
      state.unshuffled.length = 0
      state.currentIndex = -1
    },
    currentIndex (state, value) {
      state.currentIndex = value
    },
    splice (state, { start, size, items = [] }) {
      state.tracks.splice(start, size, ...items)
    },
    push (state, { items = [], to = state.tracks }) {
      to.push(...items)
    },
    clean (state, array = state.tracks) {
      array.length = 0
    },
    controller (state, controller: AbortController | undefined) {
      state.shuffleAbortController = controller
    },
    tracks (state, value) {
      state.tracks = value
    },
    reorder (state, { oldIndex, newIndex }) {
      // called when the user uses drag / drop to reorder
      // tracks in queue

      const [track] = state.tracks.splice(oldIndex, 1)
      state.tracks.splice(newIndex, 0, track)

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
    append ({ dispatch, state }, { track, index = state.tracks.length }) {
      return dispatch('appendMany', { tracks: [track], index })
    },

    async appendMany ({ commit, state }, { tracks, index = state.tracks.length }) {
      logger.info(
        'Enqueueing tracks',
        tracks.map((track: Track) => [track.artist?.name, track.title].join(' - '))
      )

      const shouldPlay = state.tracks.length === 0
      if (shouldPlay) {
        index = 0
        state.currentIndex = 0
      }

      if (index >= state.tracks.length) {
        // we simply push to the end
        commit('push', { items: tracks })
      } else {
        // we insert the track at given position
        commit('splice', { start: index, size: 0, items: tracks })
      }

      // If the queue is shuffled, push back to the original queue
      if (state.unshuffled.length) {
        commit('push', { items: tracks, to: state.unshuffled })
      }

      if (shouldPlay) {
        const { play } = await useWebAudioPlayer()
        return play()
      }
    },

    async cleanTrack ({ state, dispatch, commit }, index) {
      const { stop, play } = await useWebAudioPlayer()

      // are we removing currently playing track
      const current = index === state.currentIndex
      if (current) stop()

      commit('splice', { start: index, size: 1 })

      if (index < state.currentIndex) {
        commit('currentIndex', state.currentIndex - 1)
      } else if (index > 0 && index === state.tracks.length && current) {
        // If you delete the last track of the queue while it's
        // playing we set current index to the previous one to
        // avoid the queue tab from being stuck because the player
        // disappeared cf #1092
        commit('currentIndex', state.tracks.length - 1)
      } else if (current) {
        // we play next track, which now have the same index
        commit('currentIndex', index)
      }

      if (state.tracks.length > state.currentIndex) {
        play()
      }

      if (state.currentIndex + 1 === state.tracks.length) {
        return dispatch('radios/populateQueue', null, { root: true })
      }
    },

    last ({ state, dispatch }) {
      return dispatch('currentIndex', state.tracks.length - 1)
    },
    async currentIndex ({ commit, state, rootState, dispatch }, index) {
      commit('currentIndex', index)

      // TODO (wvffle): Move to useRadio
      if (index === state.tracks.length - 1 && rootState.radios.running) {
        return dispatch('radios/populateQueue', null, { root: true })
      }
    },
    async clean ({ dispatch, state }) {
      const { stop } = await useWebAudioPlayer()
      stop()

      await dispatch('radios/stop', null, { root: true })
      state.tracks.length = 0
      state.unshuffled.length = 0
      state.shuffleAbortController = undefined
      await dispatch('currentIndex', -1)
    },

    async shuffle ({ commit, dispatch, state }) {
      const { play, stop } = await useWebAudioPlayer()
      stop()

      logger.time('Shuffling')
      const abortController = new AbortController()
      commit('controller', abortController)

      // This should be rather quick, as it doesn't re-render the UI
      commit('clean', state.unshuffled)
      commit('push', { items: state.tracks, to: state.unshuffled })
      commit('clean')

      await deferredAppend(state.unshuffled, state.tracks, {
        signal: abortController.signal,
        mapChunk: shuffle,
        mapChunks: shuffle,
        async afterChunk (i) {
          if (i === 0) {
            await dispatch('currentIndex', 0)
            play()
          }
        }
      })

      commit('controller', undefined)
      logger.timeEnd('Shuffling')
    },

    async unshuffle ({ commit, dispatch, state }, rehydration = false) {
      const { play, stop } = await useWebAudioPlayer()
      stop()

      state.shuffleAbortController?.abort()
      const abortController = new AbortController()
      commit('controller', abortController)
      commit('clean')

      await deferredAppend(state.unshuffled, state.tracks, {
        signal: abortController.signal,
        async afterChunk (i) {
          if (i === 0 && !rehydration) {
            await dispatch('currentIndex', 0)
            play()
          }
        }
      })

      commit('clean', state.unshuffled)
      commit('controller', undefined)
    }
  }
}

export default store
