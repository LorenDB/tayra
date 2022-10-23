import type { Track, Upload } from '~/types'

import { computedAsync, useStorage } from '@vueuse/core'
import { shuffle as shuffleArray, uniq } from 'lodash-es'
import { getMany, setMany } from 'idb-keyval'
import { useClamp } from '@vueuse/math'
import { computed } from 'vue'

import axios from 'axios'

// import useWebWorker from '~/composables/useWebWorker'

// const { post, onMessageReceived } = useWebWorker('queue')

export interface QueueTrackSource {
  uuid: string
  mimetype: string
  bitrate?: number
  url: string
  duration?: number
}

export interface QueueTrack {
  id: number
  title: string
  artistName: string
  albumTitle: string

  // TODO: Add urls for those
  coverUrl: string
  artistId: number
  albumId: number

  sources: QueueTrackSource[]
}

// Queue
export const tracks = useStorage('queue:tracks', [] as number[])
const tracksById = computedAsync(async () => {
  const trackObjects = await getMany(uniq(tracks.value))
  return trackObjects.reduce((acc, track) => {
    acc[track.id] = track
    return acc
  }, {}) as Record<number, QueueTrack>
}, {})

export const queue = computed(() => {
  const indexedTracks = tracksById.value

  if (isShuffled.value) {
    return shuffledIds.value.map(id => indexedTracks[id]).filter(i => i)
  }

  return tracks.value.map(id => indexedTracks[id]).filter(i => i)
})

const createQueueTrack = async (track: Track): Promise<QueueTrack> => {
  if (track.uploads.length === 0) {
    // we don't have any information for this track, we need to fetch it
    const { uploads } = await axios.get(`tracks/${track.id}/`)
      .then(response => response.data as Track, () => ({ uploads: [] as Upload[] }))

    track.uploads = uploads
  }

  return {
    id: track.id,
    title: track.title,
    // TODO (wvffle): i18n
    artistName: track.artist?.name ?? 'Unknown artist',
    // TODO (wvffle): i18n
    albumTitle: track.album?.title ?? 'Unknown album',
    artistId: track.artist?.id ?? -1,
    albumId: track.album?.id ?? -1,
    coverUrl: (track.cover?.urls ?? track.album?.cover?.urls ?? track.artist?.cover?.urls)?.original
      ?? new URL('~/assets/audio/default-cover.png', import.meta.url).href,
    sources: track.uploads.map(upload => ({
      uuid: upload.uuid,
      mimetype: upload.mimetype,
      bitrate: upload.bitrate,
      url: upload.listen_url
    }))
  }
}

export const enqueue = async (...newTracks: Track[]) => {
  const queueTracks = await Promise.all(newTracks.map(createQueueTrack))
  await setMany(queueTracks.map(track => [track.id, track]))

  const ids = queueTracks.map(track => track.id)
  tracks.value.push(...ids)

  // Shuffle new tracks
  if (isShuffled.value) {
    shuffledIds.value.push(...shuffleArray(ids))
  }
}

// Current Index
export const currentIndex = useClamp(useStorage('queue:index', 0), 0, () => tracks.value.length)
export const currentTrack = computed(() => queue.value[currentIndex.value])

// Play track
export const playTrack = async (trackIndex: number, force = false) => {
  const { currentSound } = await import('~/composables/audio/tracks')
  const { isPlaying } = await import('~/composables/audio/player')

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
export const hasPrevious = computed(() => /* looping.value === LoopingMode.LoopQueue || */ currentIndex.value !== 0)
export const playPrevious = async () => {
  const { looping, LoopingMode } = await import('~/composables/audio/player')

  // Loop entire queue / change track to the next one
  if (looping.value === LoopingMode.LoopQueue && currentIndex.value === 0) {
    // Loop track programmatically if it is the only track in the queue
    if (tracks.value.length === 1) return playTrack(currentIndex.value, true)
    return playTrack(tracks.value.length - 1)
  }

  return playTrack(currentIndex.value - 1)
}

// Next track
export const hasNext = computed(() => /* looping.value === LoopingMode.LoopQueue || */ currentIndex.value !== tracks.value.length - 1)
export const playNext = async () => {
  const { looping, LoopingMode } = await import('~/composables/audio/player')

  // Loop entire queue / change track to the next one
  if (looping.value === LoopingMode.LoopQueue && currentIndex.value === tracks.value.length - 1) {
    // Loop track programmatically if it is the only track in the queue
    if (tracks.value.length === 1) return playTrack(currentIndex.value, true)
    return playTrack(0)
  }

  return playTrack(currentIndex.value + 1)
}

// Shuffle
const shuffledIds = useStorage('queue:tracks:shuffled', [] as number[])
export const isShuffled = computed(() => shuffledIds.value.length !== 0)
export const shuffle = () => {
  if (isShuffled.value) {
    shuffledIds.value.length = 0
    return
  }

  shuffledIds.value = shuffleArray(tracks.value)
}
