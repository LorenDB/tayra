import type { Module } from 'vuex'
import type { RootState } from '~/store/index'

import time from '~/utils/time'

export enum LoopState {
  NO_LOOP,
  LOOP_CURRENT,
  LOOP_QUEUE
}

export interface State {
  maxConsecutiveErrors: number
  errorCount: number
  playing: boolean
  isLoadingAudio: boolean
  volume: number
  lastVolume: number
  duration: number
  currentTime: number
  errored: boolean
  looping: LoopState
}

const store: Module<State, RootState> = {
  namespaced: true,
  state: {
    maxConsecutiveErrors: 5,
    errorCount: 0,
    playing: false,
    isLoadingAudio: false,
    volume: 1,
    lastVolume: 0.5,
    duration: 0,
    currentTime: 0,
    errored: false,
    looping: LoopState.NO_LOOP
  },
  mutations: {
    reset (state) {
      state.errorCount = 0
      state.playing = false
    },
    volume (state, value: number) {
      state.volume = Math.min(Math.max(value, 0), 1)
    },
    lastVolume (state, value: number) {
      state.lastVolume = Math.min(Math.max(value, 0), 1)
    },
    incrementVolume (state, value) {
      state.volume = Math.min(Math.max(value, 0), 1)
    },
    incrementErrorCount (state) {
      state.errorCount += 1
    },
    resetErrorCount (state) {
      state.errorCount = 0
    },
    duration (state, value) {
      state.duration = value
    },
    errored (state, value) {
      state.errored = value
    },
    currentTime (state, value) {
      state.currentTime = value
    },
    looping (state, value: LoopState) {
      state.looping = value
    },
    playing (state, value) {
      state.playing = value
    },
    toggleLooping (state) {
      switch (state.looping) {
        case LoopState.NO_LOOP:
          state.looping = LoopState.LOOP_CURRENT
          break
        case LoopState.LOOP_CURRENT:
          state.looping = LoopState.LOOP_QUEUE
          break
        case LoopState.LOOP_QUEUE:
          state.looping = LoopState.NO_LOOP
          break
      }
    },
    isLoadingAudio (state, value) {
      state.isLoadingAudio = value
    }
  },
  getters: {
    durationFormatted: state => {
      return time.parse(Math.round(state.duration))
    },
    currentTimeFormatted: state => {
      return time.parse(Math.round(state.currentTime))
    },
    progress: state => {
      return Math.min(state.currentTime / state.duration * 100, 100)
    }
  },
  actions: {
    incrementVolume ({ commit, state }, value) {
      commit('volume', state.volume + value)
    },
    updateProgress ({ commit }, t) {
      commit('currentTime', t)
    },
    mute ({ commit, state }) {
      commit('lastVolume', state.volume)
      commit('volume', 0)
    },
    unmute ({ commit, state }) {
      commit('volume', state.lastVolume)
    }
  }
}

export default store
