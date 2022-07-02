import { useStore } from "~/store"
import { computed } from "vue"

export default () => {
  const store = useStore()
  const looping = computed(() => store.state.player.looping)
  const playing = computed(() => store.state.player.playing)
  const loading = computed(() => store.state.player.isLoadingAudio)
  const errored = computed(() => store.state.player.errored)
  const focused = computed(() => store.state.ui.queueFocused === 'player')

  const volume = computed(() => store.state.player.volume)

  const duration = computed(() => store.state.player.duration)
  const currentTime = computed(() => store.state.player.currentTime)

  const durationFormatted = computed(() => store.getters['player/durationFormatted'])
  const currentTimeFormatted = computed(() => store.getters['player/currentTimeFormatted'])

  const progress = computed(() => store.getters['player/progress']) 
  const bufferProgress = computed(() => store.state.player.bufferProgress) 

  const pause = () => store.dispatch('player/pausePlayback')
  const resume = () => store.dispatch('player/resumePlayback')

  return { 
    looping,
    playing,
    loading,
    errored,
    focused,

    volume,

    duration,
    currentTime,

    durationFormatted,
    currentTimeFormatted,

    progress,
    bufferProgress,

    pause,
    resume
  }
}