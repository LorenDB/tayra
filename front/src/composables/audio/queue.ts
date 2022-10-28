import type { Track, Upload } from '~/types'

import { computedAsync, createGlobalState, useNow, useStorage, useTimeAgo } from '@vueuse/core'
import { shuffle as shuffleArray, sum, uniq } from 'lodash-es'
import { getMany, setMany } from 'idb-keyval'
import { computed, watchEffect } from 'vue'
import { useClamp } from '@vueuse/math'

import { looping, LoopingMode, isPlaying } from '~/composables/audio/player'
import { useStore } from '~/store'

import axios from 'axios'
import { useTracks } from './tracks'

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
const tracks = useStorage('queue:tracks', [] as number[])
const shuffledIds = useStorage('queue:tracks:shuffled', [] as number[])

const isShuffled = computed(() => shuffledIds.value.length !== 0)

const tracksById = computedAsync(async () => {
  const trackObjects = await getMany(uniq(tracks.value))
  return trackObjects.reduce((acc, track) => {
    acc[track.id] = track
    return acc
  }, {}) as Record<number, QueueTrack>
}, {})

const queue = computed(() => {
  const indexedTracks = tracksById.value

  if (isShuffled.value) {
    return shuffledIds.value.map(id => indexedTracks[id]).filter(i => i)
  }

  return tracks.value.map(id => indexedTracks[id]).filter(i => i)
})

// Current Index
export const currentIndex = useClamp(useStorage('queue:index', 0), 0, () => tracks.value.length)
export const currentTrack = computed(() => queue.value[currentIndex.value])

// Use Queue
export const useQueue = createGlobalState(() => {
  const { currentSound } = useTracks()
  const store = useStore()

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
        duration: upload.duration,
        mimetype: upload.mimetype,
        bitrate: upload.bitrate,
        url: upload.listen_url
      }))
    }
  }

  // Adding tracks
  const enqueueAt = async (index: number, ...newTracks: Track[]) => {
    const queueTracks = await Promise.all(newTracks.map(createQueueTrack))
    await setMany(queueTracks.map(track => [track.id, track]))

    const ids = queueTracks.map(track => track.id)

    if (index >= tracks.value.length) {
      // we simply push to the end
      tracks.value.push(...ids)
    } else {
      // we insert the track at given position
      tracks.value.splice(index, 0, ...ids)
    }

    // Shuffle new tracks
    if (isShuffled.value) {
      shuffledIds.value.push(...shuffleArray(ids))
    }
  }

  const enqueue = async (...newTracks: Track[]) => {
    return enqueueAt(tracks.value.length, ...newTracks)
  }

  // Removing tracks
  const dequeue = async (index: number) => {
    if (currentIndex.value === index) {
      await playNext(true)
    }

    tracks.value.splice(index, 1)

    if (index <= currentIndex.value) {
      currentIndex.value -= 1
    }

    // TODO (wvffle): Check if removing last element works well
  }

  // Play track
  const playTrack = async (trackIndex: number, force = false) => {
    if (isPlaying.value) currentSound.value?.pause()

    if (force && currentIndex.value === trackIndex) {
      currentSound.value?.seekTo(0)
      if (isPlaying.value) currentSound.value?.play()
      return
    }

    currentIndex.value = trackIndex
  }

  // Previous track
  const hasPrevious = computed(() => looping.value === LoopingMode.LoopQueue || currentIndex.value !== 0)
  const playPrevious = async (force = false) => {
    // Loop entire queue / change track to the next one
    if (looping.value === LoopingMode.LoopQueue && currentIndex.value === 0 && force !== true) {
      // Loop track programmatically if it is the only track in the queue
      if (tracks.value.length === 1) return playTrack(currentIndex.value, true)
      return playTrack(tracks.value.length - 1)
    }

    return playTrack(currentIndex.value - 1)
  }

  // Next track
  const hasNext = computed(() => looping.value === LoopingMode.LoopQueue || currentIndex.value !== tracks.value.length - 1)
  const playNext = async (force = false) => {
    // Loop entire queue / change track to the next one
    if (looping.value === LoopingMode.LoopQueue && currentIndex.value === tracks.value.length - 1 && force !== true) {
      // Loop track programmatically if it is the only track in the queue
      if (tracks.value.length === 1) return playTrack(currentIndex.value, true)
      return playTrack(0)
    }

    return playTrack(currentIndex.value + 1)
  }

  // Reorder
  const reorder = (from: number, to: number) => {
    const [id] = tracks.value.splice(from, 1)
    tracks.value.splice(to, 0, id)

    const current = currentIndex.value
    if (current === from) {
      currentIndex.value = to
      return
    }

    if (from < current && to >= current) {
      // item before was moved after
      currentIndex.value -= 1
    }

    if (from > current && to <= current) {
      // item after was moved before
      currentIndex.value += 1
    }
  }

  // Shuffle
  const shuffle = () => {
    if (isShuffled.value) {
      shuffledIds.value.length = 0
      return
    }

    shuffledIds.value = shuffleArray(tracks.value)
  }

  const reshuffleUpcomingTracks = () => {
    // TODO: Test if needed to add 1 to currentIndex
    const listenedTracks = shuffledIds.value.slice(0, currentIndex.value)
    const upcomingTracks = shuffledIds.value.slice(currentIndex.value)

    listenedTracks.push(...shuffleArray(upcomingTracks))
    shuffledIds.value = listenedTracks
  }

  // Ends in
  const now = useNow()
  const endsIn = useTimeAgo(computed(() => {
    const seconds = sum(
      queue.value
        .slice(currentIndex.value)
        .map((track) => track.sources[0]?.duration ?? 0)
    )

    const date = new Date(now.value)
    date.setSeconds(date.getSeconds() + seconds)
    return date
  }))

  // Radio queue populating
  watchEffect(() => {
    if (store.state.radios.running && currentIndex.value === tracks.value.length - 1) {
      console.log('POPULATING QUEUE FROM RADIO')
      return store.dispatch('radios/populateQueue')
    }
  })

  return {
    tracks,
    queue,
    enqueueAt,
    enqueue,
    dequeue,
    currentIndex,
    currentTrack,
    playTrack,
    hasPrevious,
    hasNext,
    playPrevious,
    playNext,
    isShuffled,
    shuffle,
    reshuffleUpcomingTracks,
    reorder,
    endsIn
  }
})
