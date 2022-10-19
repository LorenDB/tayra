import { tryOnMounted, useIntervalFn, useRafFn, useStorage, whenever } from '@vueuse/core'
import { currentSound, createTrack } from '~/composables/audio/tracks'
import { computed, ref, watch, watchEffect, type Ref } from 'vue'
import { setGain } from './audio-api'

import store from '~/store'
import axios from 'axios'

import useQueue from '~/composables/audio/useQueue'

const { currentIndex, currentTrack } = useQueue()

export const isPlaying = ref(false)

watch(isPlaying, (playing) => {
  const sound = currentSound.value
  if (!sound) return

  if (playing) {
    sound.play()
    return
  }

  sound.pause()
})

// Create first track when we initalize the page
export const initializeFirstTrack = () => tryOnMounted(() => {
  createTrack(currentIndex.value)
})

// Volume
const lastVolume = useStorage('player:last-volume', 0.7)

export const volume: Ref<number> = useStorage('player:volume', 0.7)
watch(volume, (to, from) => setGain(to))

export const mute = () => {
  if (volume.value > 0) {
    lastVolume.value = volume.value
    volume.value = 0
    return
  }

  if (lastVolume.value === 0) {
    volume.value = 0.7
    return
  }

  volume.value = lastVolume.value
}

// Looping
export enum LoopingMode {
  None,
  LoopTrack,
  LoopQueue
}

const MODE_MAX = 1 + Math.max(...Object.values(LoopingMode).filter(mode => typeof mode === 'number') as number[])

export const looping: Ref<number> = useStorage('player:looping', LoopingMode.None)
export const toggleLooping = () => {
  looping.value += 1
  looping.value %= MODE_MAX
}

watchEffect(() => {
  const sound = currentSound.value
  if (!sound) return
  sound.looping = looping.value === LoopingMode.LoopTrack
})

watch(currentSound, sound => {
  sound?.onSoundLoop(() => {
    currentTime.value = 0
  })
})

// Duration
export const duration = ref(0)
watchEffect(() => {
  const sound = currentSound.value
  if (sound?.isLoaded.value === true) {
    duration.value = sound.duration ?? 0
    currentTime.value = sound.currentTime
    return
  }

  duration.value = 0
})

// Current time
export const currentTime = ref(0)
useIntervalFn(() => {
  const sound = currentSound.value
  if (!sound) {
    currentTime.value = 0
    return
  }

  currentTime.value = sound.currentTime
}, 1000)

// Submit listens
const listenSubmitted = ref(false)
whenever(listenSubmitted, async () => {
  console.log('Listening submitted!')
  if (!store.state.auth.authenticated) return
  if (!currentTrack.value) return

  await axios.post('history/listenings/', { track: currentTrack.value.id })
    .catch((error) => console.error('Could not record track in history', error))
})

watch(currentTime, (time) => {
  const sound = currentSound.value
  if (!sound) {
    listenSubmitted.value = false
    return
  }

  // https://listenbrainz.readthedocs.io/en/latest/users/api/core.html?highlight=half#post--1-submit-listens
  listenSubmitted.value = time > Math.min(sound.duration / 2, 4 * 60)
})

// Seeking
export const seekBy = async (seconds: number) => {
  const sound = currentSound.value
  if (!sound) return

  await sound.seekBy(seconds)
  currentTime.value = sound.currentTime
}

export const seekTo = async (seconds: number) => {
  const sound = currentSound.value
  if (!sound) return

  await sound.seekTo(seconds)
  currentTime.value = sound.currentTime
}

// Buffer progress
export const bufferProgress = ref(0)
useIntervalFn(() => {
  const sound = currentSound.value
  if (!sound) {
    bufferProgress.value = 0
    return
  }

  bufferProgress.value = sound.buffered / sound.duration * 100
}, 1000)

// Progress
export const progress = ref(0)
useRafFn(() => {
  const sound = currentSound.value
  if (!sound) {
    progress.value = 0
    return
  }

  progress.value = sound.currentTime / sound.duration * 100
})

// Loading
export const loading = computed(() => {
  const sound = currentSound.value
  if (!sound) return false
  return !sound.isLoaded.value
})
