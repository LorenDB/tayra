import type { Track } from '~/types'

import { isPlaying, looping, LoopingMode } from '~/composables/audio/player'
import { currentSound } from '~/composables/audio/tracks'
import { toReactive, useStorage } from '@vueuse/core'
import { shuffle as shuffleArray } from 'lodash-es'
import { useClamp } from '@vueuse/math'
import { computed } from 'vue'

// import useWebWorker from '~/composables/useWebWorker'

// const { post, onMessageReceived } = useWebWorker('queue')

// Queue
export const tracks = toReactive(useStorage('queue:tracks', [] as Track[]))
export const queue = computed(() => {
  if (isShuffled.value) {
    const tracksById = tracks.reduce((acc, track) => {
      acc[track.id] = track
      return acc
    }, {} as Record<number, Track>)

    return shuffledIds.value.map(id => tracksById[id])
  }

  return tracks
})

export const enqueue = (...newTracks: Track[]) => {
  tracks.push(...newTracks)

  // Shuffle new tracks
  if (isShuffled.value) {
    shuffledIds.value.push(...shuffleIds(newTracks))
  }
}

// Current Index
export const currentIndex = useClamp(useStorage('queue:index', 0), 0, () => tracks.length)
export const currentTrack = computed(() => tracks[currentIndex.value])

// Play track
export const playTrack = async (trackIndex: number, force = false) => {
  if (isPlaying.value) currentSound.value?.pause()

  if (force && currentIndex.value === trackIndex) {
    currentSound.value?.seekTo(0)
    if (isPlaying.value) currentSound.value?.play()
    return
  }

  currentIndex.value = trackIndex
  if (isPlaying.value) currentSound.value?.play()
}

// Previous track
export const hasPrevious = computed(() => looping.value === LoopingMode.LoopQueue || currentIndex.value !== 0)
export const playPrevious = async () => {
  // Loop entire queue / change track to the next one
  if (looping.value === LoopingMode.LoopQueue && currentIndex.value === 0) {
    // Loop track programmatically if it is the only track in the queue
    if (tracks.length === 1) return playTrack(currentIndex.value, true)
    return playTrack(tracks.length - 1)
  }

  return playTrack(currentIndex.value - 1)
}

// Next track
export const hasNext = computed(() => looping.value === LoopingMode.LoopQueue || currentIndex.value !== tracks.length - 1)
export const playNext = async () => {
  // Loop entire queue / change track to the next one
  if (looping.value === LoopingMode.LoopQueue && currentIndex.value === tracks.length - 1) {
    // Loop track programmatically if it is the only track in the queue
    if (tracks.length === 1) return playTrack(currentIndex.value, true)
    return playTrack(0)
  }

  return playTrack(currentIndex.value + 1)
}

// Shuffle
const shuffleIds = (tracks: Track[]) => shuffleArray(tracks.map(track => track.id))
const shuffledIds = useStorage('queue:shuffled-ids', [] as number[])
export const isShuffled = computed(() => shuffledIds.value.length !== 0)
export const shuffle = () => {
  if (isShuffled.value) {
    shuffledIds.value.length = 0
    return
  }

  shuffledIds.value = shuffleIds(tracks)
}
