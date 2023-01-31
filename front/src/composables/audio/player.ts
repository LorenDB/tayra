import { createGlobalState, tryOnMounted, useIntervalFn, useRafFn, useStorage, useTimeoutFn, whenever } from '@vueuse/core'
import { computed, ref, watch, watchEffect, type Ref } from 'vue'
import { useTracks } from '~/composables/audio/tracks'
import { setGain } from './audio-api'

import { useQueue, currentIndex, currentTrack } from './queue'
import { useStore } from '~/store'

import axios from 'axios'

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

// Is playing
export const isPlaying = ref(false)

// Use Player
export const usePlayer = createGlobalState(() => {
  const { currentSound } = useTracks()
  const { playNext } = useQueue()

  watchEffect(() => {
    const sound = currentSound.value
    if (!sound) return

    if (isPlaying.value) {
      return sound.play()
    }

    return sound.pause()
  })

  // Create first track when we initialize the page
  // NOTE: We want to have it called only once, hence we're using createGlobalState
  const initializeFirstTrack = createGlobalState(() => tryOnMounted(() => {
    const { initialize } = useTracks()
    initialize()

    const { trackRadioPopulating } = useQueue()
    trackRadioPopulating()

    trackListenSubmissions()
  }))

  // Volume
  const lastVolume = useStorage('player:last-volume', 0.7)

  const volume: Ref<number> = useStorage('player:volume', 0.7)
  watch(volume, (gain) => setGain(gain), { immediate: true })

  const mute = () => {
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
  const duration = ref(0)
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
  const currentTime = ref(0)
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
  const trackListenSubmissions = () => {
    const store = useStore()
    whenever(listenSubmitted, async () => {
      console.log('Listening submitted!')
      if (!store.state.auth.authenticated) return
      if (!currentTrack.value) return

      await axios.post('history/listenings/', { track: currentTrack.value.id })
        .catch((error) => console.error('Could not record track in history', error))
    })
  }

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
  const seekBy = async (seconds: number) => {
    const sound = currentSound.value
    if (!sound) return

    await sound.seekBy(seconds)
    currentTime.value = sound.currentTime
  }

  const seekTo = async (seconds: number) => {
    const sound = currentSound.value
    if (!sound) return

    await sound.seekTo(seconds)
    currentTime.value = sound.currentTime
  }

  // Buffer progress
  const bufferProgress = ref(0)
  useIntervalFn(() => {
    const sound = currentSound.value
    if (!sound) {
      bufferProgress.value = 0
      return
    }

    bufferProgress.value = sound.buffered / sound.duration * 100
  }, 1000)

  // Progress
  const progress = ref(0)

  // Loading
  const loading = computed(() => {
    const sound = currentSound.value
    if (!sound) return false
    return !sound.isLoaded.value
  })

  // Errored
  const errored = computed(() => {
    const sound = currentSound.value
    if (!sound) return false
    return sound.isErrored.value
  })

  const { start: startErrorTimeout, stop: stopErrorTimeout } = useTimeoutFn(() => {
    if (looping.value !== LoopingMode.LoopTrack) {
      return playNext()
    }

    isPlaying.value = false
  }, 3000, { immediate: false })

  watch(currentIndex, stopErrorTimeout)
  whenever(errored, startErrorTimeout)

  return {
    initializeFirstTrack,
    isPlaying,
    volume,
    mute,
    looping,
    LoopingMode,
    toggleLooping,
    duration,
    currentTime,
    seekBy,
    seekTo,
    bufferProgress,
    progress,
    loading,
    errored
  }
})
