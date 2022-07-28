import type { IAudioBufferSourceNode, IAudioContext } from 'standardized-audio-context'
import type { Track } from '~/types'

import { AudioContext, AudioBufferSourceNode } from 'standardized-audio-context'
import { ref, reactive, computed, watchEffect, nextTick, shallowRef } from 'vue'
import { useRafFn, watchDebounced, computedEager } from '@vueuse/core'
import { uniq } from 'lodash-es'
import LRUCache from 'lru-cache'
import store from '~/store'
import axios from 'axios'

import useTrackSources from './useTrackSources'
import { LoopState } from '~/store/player'
import useLogger from '../useLogger'
import toLinearVolumeScale from './toLinearVolumeScale'

const TO_PRELOAD = 5

const context = new AudioContext()
const logger = useLogger()

//
// Audio loading
//

// Maximum of 20 song buffers can be cached
const bufferCache = new LRUCache<string, AudioBuffer>({
  max: 20,
  disposeAfter (buffer: AudioBuffer, key: string) {
    // In case we've disposed the current buffer from cache, add it back
    if (buffer === currentNode.value?.buffer) {
      bufferCache.set(key, buffer)
    }
  }
})

const loadTrackBuffer = async (track: Track, abortSignal?: AbortSignal) => {
  if (bufferCache.has(track.id)) {
    return bufferCache.get(track.id)
  }

  const sources = await useTrackSources(track, abortSignal)
  if (!sources.length) return null

  // TODO: Quality picker
  const response = await axios.get(sources[0].url, {
    responseType: 'arraybuffer'
  })

  const buffer = await context.decodeAudioData(response.data)
  bufferCache.set(track.id, buffer)

  return buffer
}

const ended = () => {
  // Since pause() also emits ended event, we need to check if we're playing currently
  if (playerState.playing) {
    next()
  }
}

let globalAbortController: AbortController
const playTrack = async (track: Track) => {
  // Abort previous play request
  globalAbortController?.abort()
  const abortController = globalAbortController = new AbortController()

  const buffer = await loadTrackBuffer(track, abortController.signal)
  if (abortController.signal.aborted) return false
  if (buffer === null) return null

  const source = new AudioBufferSourceNode(context, {
    buffer
  })

  source.connect(gainNode)
  source.addEventListener('ended', ended)
  return source
}

// Preload current track buffer
const currentTrack = computed(() => store.state.queue.tracks[store.state.queue.currentIndex])
if (currentTrack.value) {
  loadTrackBuffer(currentTrack.value)
}

//
// Audio gain
//
const gainNode = context.createGain()
gainNode.connect(context.destination)

watchEffect(() => (gainNode.gain.value = toLinearVolumeScale(store.state.player.volume)))

const unmute = () => store.dispatch('player/unmute')
const mute = () => store.dispatch('player/mute')

const toggleMute = () => store.state.player.volume === 0
  ? unmute()
  : mute()

//
// Audio playback
//
const currentNode = shallowRef<IAudioBufferSourceNode<IAudioContext> | null>(null)
const playerState = reactive({
  playing: false,
  startedAt: 0,
  pausedAt: 0
})

const play = () => {
  if (context.state === 'suspended') context.resume()
  playerState.playing = true
}

const pause = () => {
  playerState.playing = false
}

const stop = () => {
  if (currentNode.value) {
    progress.value = 0
    stopNode(currentNode.value)
    currentNode.value = null
    playerState.playing = false
    playerState.pausedAt = 0
  }
}

const seek = (addTime: number) => {
  if (currentNode.value?.buffer) {
    progress.value = Math.max(0, Math.min(100, progress.value + (addTime / currentNode.value?.buffer?.duration) * 100))
  }
}

const isLastTrack = computedEager(() => store.state.queue.currentIndex + 1 >= store.state.queue.tracks.length)
const willLoopQueue = computedEager(() => store.state.player.looping === LoopState.LOOP_QUEUE && isLastTrack.value)
const next = async () => {
  // Looping queue
  if (willLoopQueue.value) {
    return store.dispatch('queue/currentIndex', 0)
  }

  // Pause if last
  if (isLastTrack.value) {
    progress.value = 0

    // We need to wait for the first debounce tick
    await nextTick()
    // We need to wait for the play() to run after seeking to the beginning
    await nextTick()

    return pause()
  }

  // Play next track
  if (playerState.pausedAt === 0) {
    stop()
    await store.dispatch('queue/currentIndex', store.state.queue.currentIndex + 1)
    play()
  }
}

const previous = async () => {
  if (store.state.queue.currentIndex > 0 && time.value < 3) {
    await store.dispatch('queue/currentIndex', store.state.queue.currentIndex - 1)
  } else {
    progress.value = 0
  }
}

// Stop node, remove handlers and disconnect from gain node
const stopNode = (node: IAudioBufferSourceNode<IAudioContext> | null) => {
  pauseProgress()
  if (node === null) return

  node.removeEventListener('ended', ended)
  node.stop()
  node.disconnect(gainNode)
}

const errored = ref(false)

// Play handler
watchDebounced([
  () => playerState.playing,
  currentTrack
], async () => {
// watchEffect(async () => {
  if (playerState.playing && currentTrack.value) {
    stopNode(currentNode.value)
    currentNode.value = null

    const source = await playTrack(currentTrack.value)

    // Play request is aborted
    if (source === false) return

    // Play request errored
    if (source === null) {
      errored.value = true
      return
    }

    // NOTE: We've now list reactivity tracking after the first await call

    if (playerState.pausedAt !== 0) {
      // Start from the paused moment
      source.start(0, playerState.pausedAt - playerState.startedAt)
      playerState.pausedAt = 0
    } else {
      // Start from the beginning
      source.start()
      playerState.startedAt = context.currentTime
    }

    currentNode.value = source
    resumeProgress()
  }
}, { debounce: 0 })

// Pause handler
watchEffect(() => {
  if (!playerState.playing && currentTrack.value && currentNode.value) {
    playerState.pausedAt = context.currentTime
    currentNode.value.stop()
    pauseProgress()
  }
})

// Looping handler
watchEffect(() => {
  if (currentNode.value) {
    currentNode.value.loop = store.state.player.looping === LoopState.LOOP_CURRENT
      || (store.state.player.looping === LoopState.LOOP_QUEUE && store.state.queue.tracks.length === 1)
  }
})

// Preloading handler
watchDebounced([
  // on index change
  () => store.state.queue.currentIndex,
  // on new track
  () => store.state.queue.tracks,
  // on shuffle/unshuffle
  () => store.state.queue.shuffleAbortController
], async () => {
  const index = store.state.queue.currentIndex
  const tracks = store.state.queue.tracks

  // Try to preload 1 previous track and TO_PRELOAD - 1 future tracks
  const preloads = uniq([-2, ...Array(TO_PRELOAD - 1).keys()].map(i => {
    const preloadIndex = (index + i + 1) % tracks.length
    return tracks[preloadIndex]
  })).filter(track => track && !bufferCache.has(track.id))

  if (!preloads.length) {
    return
  }

  await Promise.all(preloads.map(async track => {
    const msg = `Preloading ${track.artist?.name ?? 'Unknown artist'} - ${track.title}`

    logger.time(msg)
    await loadTrackBuffer(track)
    logger.timeEnd(msg)
  }))

  logger.debug(`Preloaded ${preloads.length} tracks`)
}, { immediate: true, debounce: 1000 })

// Progress getter and setter
const time = ref(0)
const progress = computed({
  // Get progress
  get: () => currentNode.value?.buffer
    ? Math.min(time.value / currentNode.value.buffer.duration * 100, 100)
    : 0,
  // Seek to percent
  set: async (percent: number) => {
    // Initialize track if we haven't already
    if (!currentNode.value?.buffer) {
      await play()
      progress.value = percent
      return
    }

    const time = percent / 100 * currentNode.value.buffer.duration
    pause()
    playerState.startedAt = context.currentTime - time
    playerState.pausedAt = context.currentTime
    await nextTick()
    play()
  }
})

// Progress animation loop
const { resume: resumeProgress, pause: pauseProgress } = useRafFn(() => {
  if (playerState.playing) {
    time.value = context.currentTime - playerState.startedAt
    return
  }

  time.value = 0
}, { immediate: false })

// Animation fix for looped tracks and track listened handler
const isListened = ref(false)
watchEffect(() => {
  // When we are done but looping, reset startedAt
  if (progress.value === 100 && currentNode.value?.loop) {
    playerState.startedAt = context.currentTime
  }

  // If unathenticated, do not track track listenings
  if (!store.state.auth.authenticated) return

  // When we are half-way through, send track listened
  if (progress.value > 50 && !isListened.value) {
    isListened.value = true
    return axios.post('history/listenings/', { track: currentTrack.value.id })
      .catch((error) => logger.error('Could not record track in history', error))
  }

  // When we are before half-way through, reset listened state
  if (currentNode.value && progress.value <= 50 && isListened.value) {
    isListened.value = false
  }
})

// Exports
export default () => ({
  // Audio loading
  loadTrackBuffer,
  // Audio gain
  toggleMute,
  unmute,
  mute,
  // Audio playback
  play,
  pause,
  stop,
  seek,
  next,
  previous,
  errored,
  time,
  progress,
  duration: computed(() => currentNode.value?.buffer?.duration ?? 0),
  playing: computedEager(() => playerState.playing),
  loading: computedEager(() => playerState.playing && currentTrack.value && !currentNode.value)
})
