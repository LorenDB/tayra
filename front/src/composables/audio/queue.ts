import type { Track, Upload } from '~/types'

import { createGlobalState, useNow, useStorage, useTimeAgo, whenever } from '@vueuse/core'
import { shuffle as shuffleArray, sum } from 'lodash-es'
import { computed, ref, shallowReactive, watchEffect } from 'vue'
import { getMany, setMany } from 'idb-keyval'
import { useClamp } from '@vueuse/math'

import { looping, LoopingMode, isPlaying } from '~/composables/audio/player'
import { useStore } from '~/store'

import { useTracks } from '~/composables/audio/tracks'
import { gettext } from '~/init/locale'

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
  position?: number

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

const tracksById = shallowReactive(new Map<number, QueueTrack>())
const fetchingTracks = ref(false)
watchEffect(async () => {
  if (fetchingTracks.value) return

  const allTracks = new Set(tracks.value)
  const addedIds = new Set(allTracks)

  for (const id of tracksById.keys()) {
    if (allTracks.has(id)) {
      // Track in queue, so remove it from the new ids set
      addedIds.delete(id)
    } else {
      // Track removed from queue, so remove it from the object
      tracksById.delete(id)
    }
  }

  if (addedIds.size > 0) {
    fetchingTracks.value = true
    try {
      const trackInfos: QueueTrack[] = await getMany([...addedIds])
      for (const track of trackInfos.filter(i => i)) {
        tracksById.set(track.id, track)
      }
    } catch (error) {
      console.error(error)
    } finally {
      fetchingTracks.value = false
    }
  }
})

const queue = computed<QueueTrack[]>(() => {
  const ids = isShuffled.value
    ? shuffledIds.value
    : tracks.value

  return ids.map(id => tracksById.get(id)).filter((i): i is QueueTrack => !!i)
})

// Current Index
export const currentIndex = useClamp(useStorage('queue:index', 0), 0, () => tracks.value.length)
export const currentTrack = computed(() => queue.value[currentIndex.value])

// Use Queue
export const useQueue = createGlobalState(() => {
  const { currentSound } = useTracks()

  const createQueueTrack = async (track: Track): Promise<QueueTrack> => {
    const { $pgettext } = gettext

    if (track.uploads.length === 0) {
      // we don't have any information for this track, we need to fetch it
      const { uploads } = await axios.get(`tracks/${track.id}/`)
        .then(response => response.data as Track, () => ({ uploads: [] as Upload[] }))

      track.uploads = uploads
    }

    return {
      id: track.id,
      title: track.title,
      artistName: track.artist?.name ?? $pgettext('*/*/*', 'Unknown artist'),
      albumTitle: track.album?.title ?? $pgettext('*/*/*', 'Unknown album'),
      position: track.position,
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
  }

  // Play track
  const playTrack = async (trackIndex: number, forceRestartIfCurrent = false) => {
    if (isPlaying.value) currentSound.value?.pause()
    if (currentIndex.value !== trackIndex) currentSound.value?.seekTo(0)

    const shouldRestart = forceRestartIfCurrent && currentIndex.value === trackIndex
    const nextTrackIsTheSame = queue.value[trackIndex]?.id === currentTrack.value?.id

    if (shouldRestart || nextTrackIsTheSame) {
      currentSound.value?.seekTo(0)
      if (isPlaying.value) currentSound.value?.play()
      if (shouldRestart) return
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
      const id = shuffledIds.value[currentIndex.value]
      shuffledIds.value.length = 0

      // NOTE: This this looses the correct index when there are multiple tracks with the same id in the queue
      //       Since we shuffled the queue before, we probably do not even care for the correct index, just the order
      currentIndex.value = tracks.value.indexOf(id)
      return
    }

    const ids = [...tracks.value]
    const [first] = ids.splice(currentIndex.value, 1)
    shuffledIds.value = [first, ...shuffleArray(ids)]
    currentIndex.value = 0
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

  // Clear
  const clearRadio = ref(false)
  const clear = async () => {
    currentSound.value?.pause()
    currentSound.value?.seekTo(0)
    currentSound.value?.dispose()
    clearRadio.value = true
    tracks.value.length = 0
  }

  // Radio queue populating
  const trackRadioPopulating = () => {
    const store = useStore()
    watchEffect(() => {
      if (store.state.radios.running && currentIndex.value === tracks.value.length - 1) {
        console.log('POPULATING QUEUE FROM RADIO')
        return store.dispatch('radios/populateQueue')
      }
    })

    whenever(clearRadio, () => {
      clearRadio.value = false
      if (store.state.radios.running) {
        return store.dispatch('radios/stop')
      }
    })
  }

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
    endsIn,
    clear,
    trackRadioPopulating
  }
})
