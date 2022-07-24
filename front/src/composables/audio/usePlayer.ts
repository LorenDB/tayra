import type { Track } from '~/types'

import { computed, watchEffect, ref, watch } from 'vue'
import { Howler } from 'howler'
import { useRafFn, useTimeoutFn } from '@vueuse/core'
import useQueue from '~/composables/audio/useQueue'
import useSound from '~/composables/audio/useSound'
import toLinearVolumeScale from '~/composables/audio/toLinearVolumeScale'
import store from '~/store'
import axios from 'axios'

const PRELOAD_DELAY = 15

const { currentSound, loadSound, onSoundProgress } = useSound()
const { isShuffling, currentTrack, currentIndex } = useQueue()

const looping = computed(() => store.state.player.looping)
const playing = computed(() => store.state.player.playing)
const loading = computed(() => store.state.player.isLoadingAudio)
const errored = computed(() => store.state.player.errored)
const focused = computed(() => store.state.ui.queueFocused === 'player')

// Cache sound if we have currentTrack available
if (currentTrack.value) {
  loadSound(currentTrack.value)
}

// Playing
const playTrack = async (track: Track, oldTrack?: Track) => {
  const oldSound = currentSound.value

  // TODO (wvffle): Move oldTrack to watcher
  if (oldSound && track !== oldTrack) {
    oldSound.stop()
  }

  if (!track) {
    return
  }

  if (!isShuffling.value) {
    if (!track.uploads.length) {
      // we don't have any information for this track, we need to fetch it
      track = await axios.get(`tracks/${track.id}/`)
        .then(response => response.data, () => null)
    }

    if (track === null) {
      store.commit('player/isLoadingAudio', false)
      store.dispatch('player/trackErrored')
      return
    }

    currentSound.value = loadSound(track)

    if (playing.value) {
      currentSound.value.play()
      store.commit('player/playing', true)
    } else {
      store.commit('player/isLoadingAudio', false)
    }

    store.commit('player/errored', false)
    store.dispatch('player/updateProgress', 0)
  }
}

const { start: loadTrack, stop: cancelLoading } = useTimeoutFn((track, oldTrack) => {
  playTrack(track as Track, oldTrack as Track)
}, 100, { immediate: false }) as {
  start: (a: Track, b: Track) => void
  stop: () => void
}

watch(currentTrack, (track, oldTrack) => {
  cancelLoading()
  currentSound.value?.pause()
  store.commit('player/isLoadingAudio', true)
  loadTrack(track, oldTrack)
})

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
const currentTime = computed({
  get: () => store.state.player.currentTime,
  set: (time) => {
    if (time < 0 || time > duration.value) {
      return
    }

    if (!currentSound.value?.getSource() || time === currentSound.value.seek()) {
      return
    }

    currentSound.value.seek(time)

    // Update progress immediately to ensure updated UI
    progress.value = time
  }
})

const durationFormatted = computed(() => store.getters['player/durationFormatted'])
const currentTimeFormatted = computed(() => store.getters['player/currentTimeFormatted'])

// Progress
const progress = computed({
  get: () => store.getters['player/progress'],
  set: (time) => {
    if (currentSound.value?.state() === 'loaded') {
      store.state.player.currentTime = time

      const duration = currentSound.value.duration()
      currentSound.value.triggerSoundProgress(time, duration)
    }
  }
})

const bufferProgress = computed(() => store.state.player.bufferProgress)
onSoundProgress(({ node, time, duration }) => {
  const toPreload = store.state.queue.tracks[currentIndex.value + 1]
  if (!nextTrackPreloaded.value && toPreload && (time > PRELOAD_DELAY || duration - time < 30)) {
    loadSound(toPreload)
    nextTrackPreloaded.value = true
  }

  if (time > duration / 2) {
    if (!isListeningSubmitted.value) {
      store.dispatch('player/trackListened', currentTrack.value)
      isListeningSubmitted.value = true
    }
  }

  // from https://github.com/goldfire/howler.js/issues/752#issuecomment-372083163

  const { buffered, currentTime } = node

  let range = 0
  try {
    while (buffered.start(range) >= currentTime || currentTime >= buffered.end(range)) {
      range += 1
    }
  } catch (IndexSizeError) {
    return
  }

  let loadPercentage

  const start = buffered.start(range)
  const end = buffered.end(range)

  if (range === 0) {
    // easy case, no user-seek
    const loadStartPercentage = start / node.duration
    const loadEndPercentage = end / node.duration
    loadPercentage = loadEndPercentage - loadStartPercentage
  } else {
    const loaded = end - start
    const remainingToLoad = node.duration - start
    // user seeked a specific position in the audio, our progress must be
    // computed based on the remaining portion of the track
    loadPercentage = loaded / remainingToLoad
  }

  if (loadPercentage * 100 === bufferProgress.value) {
    return
  }

  store.commit('player/bufferProgress', loadPercentage * 100)
})

const observeProgress = ref(false)
useRafFn(() => {
  if (observeProgress.value && currentSound.value?.state() === 'loaded') {
    progress.value = currentSound.value.seek()
  }
})

watch(playing, async (isPlaying) => {
  if (currentSound.value) {
    if (isPlaying) {
      currentSound.value.play()
    } else {
      currentSound.value.pause()
    }
  } else {
    await playTrack(currentTrack.value)
  }

  observeProgress.value = isPlaying
})

const isListeningSubmitted = ref(false)
const nextTrackPreloaded = ref(false)
watch(currentTrack, () => (nextTrackPreloaded.value = false))

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

export default () => {
  return {
    looping,
    playing,
    loading,
    errored,
    focused,
    isListeningSubmitted,

    playTrack,

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
