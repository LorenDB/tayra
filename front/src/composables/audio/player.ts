import { getCurrentSound, createTrack } from '~/composables/audio/tracks'
import { tryOnMounted } from '@vueuse/core'
import { ref, watch } from 'vue'

import useQueue from '~/composables/audio/useQueue'

const { currentIndex } = useQueue()

export const isPlaying = ref(false)

watch(isPlaying, (playing) => {
  const sound = getCurrentSound()
  if (!sound) return

  if (playing) {
    sound.audio.play()
    return
  }

  sound.audio.pause()
})

// Create first track when we initalize the page
export const initializeFirstTrack = () => tryOnMounted(() => {
  createTrack(currentIndex.value)
})

export const _seekEnd = () => {
  const sound = getCurrentSound()
  if (!sound) return

  sound.audio.currentTime = sound.audio.duration - 3
}
