import { computed, watchEffect } from "vue"
import { Howler } from 'howler'
import useQueue from '~/composables/audio/useQueue'
import toLinearVolumeScale from '~/composables/audio/toLinearVolumeScale'
import store from "~/store"

export default () => {
  const looping = computed(() => store.state.player.looping)
  const playing = computed(() => store.state.player.playing)
  const loading = computed(() => store.state.player.isLoadingAudio)
  const errored = computed(() => store.state.player.errored)
  const focused = computed(() => store.state.ui.queueFocused === 'player')

  // Volume
  const volume = computed({
    get: () => store.state.player.volume,
    set: (value) => store.commit('player/volume', value)
  })

  watchEffect(() => Howler.volume(toLinearVolumeScale(volume.value)))

  const mute = () => store.dispatch('player/mute')
  const unmute = () => store.dispatch('player/unmute')
  const toggleMute = () => store.dispatch('player/toggleMute')

  // Time and duration
  const duration = computed(() => store.state.player.duration)
  const currentTime = computed(() => store.state.player.currentTime)

  const durationFormatted = computed(() => store.getters['player/durationFormatted'])
  const currentTimeFormatted = computed(() => store.getters['player/currentTimeFormatted'])

  // Progress
  const progress = computed(() => store.getters['player/progress']) 
  const bufferProgress = computed(() => store.state.player.bufferProgress) 

  // Controls
  const pause = () => store.dispatch('player/pausePlayback')
  const resume = () => store.dispatch('player/resumePlayback')

  const { next } = useQueue()
  const seek = (step: number) => {
    // seek right
    if (step > 0) {
      if (currentTime.value + step < duration.value) {
        store.dispatch('player/updateProgress', (currentTime.value + step))
      } else {
        next()
      }

      return
    }

    // seek left
    const position = Math.max(currentTime.value + step, 0)
    store.dispatch('player/updateProgress', position)
  }

  const togglePlayback = () => {
    if (playing.value) return pause()
    return resume()
  }

  return { 
    looping,
    playing,
    loading,
    errored,
    focused,

    volume,
    mute,
    unmute,
    toggleMute,

    duration,
    currentTime,

    durationFormatted,
    currentTimeFormatted,

    progress,
    bufferProgress,

    pause,
    resume,
    seek,
    togglePlayback
  }
}