import type { Track, Upload } from '~/types'

import { createGlobalState, useNow, useStorage, useTimeAgo, whenever } from '@vueuse/core'
import { computed, ref, shallowReactive, watchEffect } from 'vue'
import { shuffle as shuffleArray, sum } from 'lodash-es'
import { useClamp } from '@vueuse/math'
import { useStore } from '~/store'

import { looping, LoopingMode, isPlaying, usePlayer } from '~/composables/audio/player'
import { delMany, getMany, setMany } from '~/composables/data/indexedDB'
import { setGain } from '~/composables/audio/audio-api'
import { useTracks } from '~/composables/audio/tracks'

import axios from 'axios'

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
  artistName?: string
  albumTitle?: string
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
  const removedIds = new Set<number>()
  const addedIds = new Set(allTracks)

  for (const id of tracksById.keys()) {
    if (allTracks.has(id)) {
      // Track in queue, so remove it from the new ids set
      addedIds.delete(id)
    } else {
      // Track removed from queue, so remove it from the object and db later
      removedIds.add(id)
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

  if (removedIds.size > 0) {
    await delMany([...removedIds])
    for (const id of removedIds) {
      tracksById.delete(id)
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
export const currentIndex = useClamp(useStorage('queue:index', 0), 0, () => tracks.value.length - 1)
export const currentTrack = computed(() => queue.value[currentIndex.value])

// Use Queue
export const useQueue = createGlobalState(() => {
  const { currentSound } = useTracks()

  const createQueueTrack = async (track: Track, skipFetch = false): Promise<QueueTrack> => {
    const { default: store } = await import('~/store')

    if (track.uploads.length === 0 && skipFetch === false) {
      // we don't have any information for this track, we need to fetch it
      const { uploads } = await axios.get(`tracks/${track.id}/`)
        .then(response => response.data as Track, () => ({ uploads: [] as Upload[] }))

      track.uploads = uploads
    }

    return {
      id: track.id,
      title: track.title,
      artistName: track.artist?.name,
      albumTitle: track.album?.title,
      position: track.position,
      artistId: track.artist?.id ?? -1,
      albumId: track.album?.id ?? -1,
      coverUrl: (track.cover?.urls ?? track.album?.cover?.urls ?? track.artist?.cover?.urls)?.original
        ?? new URL('../../assets/audio/default-cover.png', import.meta.url).href,
      sources: track.uploads.map(upload => ({
        uuid: upload.uuid,
        duration: upload.duration,
        mimetype: upload.mimetype,
        bitrate: upload.bitrate,
        url: store.getters['instance/absoluteUrl'](upload.listen_url)
      }))
    }
  }

  const isTrack = (track: Track | boolean): track is Track => typeof track !== 'boolean'

  // Adding tracks
  async function enqueueAt (index: number, ...newTracks: Track[]): Promise<void>
  // NOTE: Only last boolean of newTracks is considered as skipFetch
  async function enqueueAt (index: number, ...newTracks: (Track | boolean)[]) : Promise<void>
  async function enqueueAt (index: number, ...newTracks: (Track | boolean)[]) : Promise<void> {
    let skipFetch = false
    if (!isTrack(newTracks[newTracks.length - 1])) {
      skipFetch = newTracks.pop() as boolean
    }

    const queueTracks = await Promise.all(newTracks.filter(isTrack).map((track) => createQueueTrack(track, skipFetch)))
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

  async function enqueue (...newTracks: Track[]): Promise<void>
  // NOTE: Only last boolean of newTracks is considered as skipFetch
  async function enqueue (...newTracks: (Track | boolean)[]): Promise<void>
  async function enqueue (...newTracks: (Track | boolean)[]): Promise<void> {
    return enqueueAt(tracks.value.length, ...newTracks)
  }

  // Removing tracks
  const dequeue = async (index: number) => {
    if (currentIndex.value === index) {
      await playNext(true)
    }

    if (isShuffled.value) {
      tracks.value.splice(tracks.value.indexOf(shuffledIds.value[index]), 1)
      shuffledIds.value.splice(index, 1)
    } else {
      tracks.value.splice(index, 1)
    }

    if (index <= currentIndex.value) {
      currentIndex.value -= 1
    }
  }

  // Play track
  const playTrack = async (trackIndex: number, forceRestartIfCurrent = false) => {
    if (isPlaying.value) await currentSound.value?.pause()
    if (currentIndex.value !== trackIndex) await currentSound.value?.seekTo(0)

    const shouldRestart = forceRestartIfCurrent && currentIndex.value === trackIndex
    const nextTrackIsTheSame = queue.value[trackIndex]?.id === currentTrack.value?.id

    if (shouldRestart || nextTrackIsTheSame) {
      await currentSound.value?.seekTo(0)
      if (isPlaying.value) await currentSound.value?.play()
      if (shouldRestart) return
    }

    currentIndex.value = trackIndex
  }

  // Previous track
  const playPrevious = async (force = false) => {
    // If we're only 3 seconds into track, we seek to the beginning
    const { currentTime } = usePlayer()
    if (currentTime.value >= 3) {
      return playTrack(currentIndex.value, true)
    }

    // Loop entire queue / change track to the next one
    if (looping.value === LoopingMode.LoopQueue && currentIndex.value === 0 && force !== true) {
      // Loop track programmatically if it is the only track in the queue
      if (tracks.value.length === 1) return playTrack(currentIndex.value, true)
      return playTrack(tracks.value.length - 1)
    }

    if (currentIndex.value === 0) {
      return playTrack(currentIndex.value, true)
    }

    return playTrack(currentIndex.value - 1)
  }

  // Next track
  const hasNext = computed(() => looping.value === LoopingMode.LoopQueue || currentIndex.value !== tracks.value.length - 1)
  const playNext = async (force = false) => {
    if (currentIndex.value === tracks.value.length - 1) {
      // Loop entire queue / change track to the next one
      if (looping.value === LoopingMode.LoopQueue && force !== true) {
        // Loop track programmatically if it is the only track in the queue
        if (tracks.value.length === 1) return playTrack(currentIndex.value, true)
        return playTrack(0)
      }

      isPlaying.value = false
    }

    return playTrack(currentIndex.value + 1)
  }

  // Reorder
  const reorder = (from: number, to: number) => {
    const list = isShuffled.value
      ? shuffledIds
      : tracks

    const [id] = list.value.splice(from, 1)
    list.value.splice(to, 0, id)

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
    await currentSound.value?.pause()
    await currentSound.value?.seekTo(0)
    currentSound.value?.dispose()

    clearRadio.value = true

    const lastTracks = [...tracks.value]
    tracks.value.length = 0
    await delMany(lastTracks)
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

    // TODO: Remove at 1.5.0
    // Migrate old queue format to the new one
    if (localStorage.queue) {
      (async () => {
        const { queue: { currentIndex: index, tracks: oldTracks } } = JSON.parse(localStorage.queue) as { queue: { currentIndex: number, tracks: Track[] } }

        const oldRadios = localStorage.radios

        if (oldTracks.length !== 0) {
          tracks.value.length = 0
          await enqueue(...oldTracks, true)
        }

        // NOTE: There is a race condition between clearing queue and adding new tracks that resets the radio.
        //       We need to reset the radio to the old state
        try {
          const radios = JSON.parse(oldRadios)
          store.commit('radios/current', radios.radios.current)
          store.commit('radios/running', radios.radios.running)
        } catch (err) {}

        currentIndex.value = index
        delete localStorage.queue
      })().catch((error) => console.error('Could not successfully migrate between queue versions', error))
    }

    if (localStorage.player) {
      try {
        const { player: { looping: loopingMode, volume } } = JSON.parse(localStorage.player) as { player: { looping: LoopingMode, volume: number }}
        looping.value = loopingMode ?? 0
        setGain(volume ?? 0.7)
        delete localStorage.player
      } catch (error) {
        console.error('Could not successfully migrate between player versions', error)
      }
    }
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
