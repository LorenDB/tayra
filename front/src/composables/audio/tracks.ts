import type { QueueTrack, QueueTrackSource } from '~/composables/audio/queue'
import type { Track, Upload } from '~/types'
import type { Sound } from '~/api/player'

import { createGlobalState, syncRef, useTimeoutFn, whenever } from '@vueuse/core'
import { computed, ref, watchEffect } from 'vue'

import { connectAudioSource } from '~/composables/audio/audio-api'
import { usePlayer } from '~/composables/audio/player'
import { useQueue } from '~/composables/audio/queue'
import { soundImplementation } from '~/api/player'

import useLRUCache from '~/composables/data/useLRUCache'
import store from '~/store'

import axios from 'axios'

const ALLOWED_PLAY_TYPES: (CanPlayTypeResult | undefined)[] = ['maybe', 'probably']
const AUDIO_ELEMENT = document.createElement('audio')

const soundPromises = new Map<number, Promise<Sound>>()
const soundCache = useLRUCache<number, Sound>({ max: 10 })

export const fetchTrackSources = async (id: number): Promise<QueueTrackSource[]> => {
  const { uploads } = await axios.get(`tracks/${id}/`)
    .then(response => response.data as Track, () => ({ uploads: [] as Upload[] }))

  return uploads.map(upload => ({
    uuid: upload.uuid,
    duration: upload.duration,
    mimetype: upload.mimetype,
    bitrate: upload.bitrate,
    url: store.getters['instance/absoluteUrl'](upload.listen_url)
  }))
}

const getTrackSources = async (track: QueueTrack): Promise<QueueTrackSource[]> => {
  const token = store.state.auth.authenticated && store.state.auth.scopedTokens.listen
  const appendToken = (url: string) => {
    if (token) {
      const newUrl = new URL(url)
      newUrl.searchParams.set('token', token)
      return newUrl.toString()
    }

    return url
  }

  if (track.sources.length === 0) {
    track.sources = await fetchTrackSources(track.id)
  }

  const sources: QueueTrackSource[] = track.sources
    .map((source) => ({
      ...source,
      url: appendToken(store.getters['instance/absoluteUrl'](source.url))
    }))

  // NOTE: Add a transcoded MP3 src at the end for browsers
  //       that do not support other codecs to be able to play it :)
  if (sources.length > 0) {
    const original = sources[0]
    const url = new URL(original.url)
    url.searchParams.set('to', 'mp3')

    const bitrate = Math.min(320000, original.bitrate ?? Infinity)
    sources.push({ uuid: 'transcoded', mimetype: 'audio/mpeg', url: url.toString(), bitrate })
  }

  return sources
    // NOTE: Filter out repeating and unplayable media types
    .filter(({ mimetype, bitrate }, index, array) => array.findIndex((upload) => upload.mimetype + upload.bitrate === mimetype + bitrate) === index)
    .filter(({ mimetype }) => ALLOWED_PLAY_TYPES.includes(AUDIO_ELEMENT.canPlayType(`${mimetype}`)))
}

// Use Tracks
export const useTracks = createGlobalState(() => {
  const createSound = async (track: QueueTrack): Promise<Sound> => {
    if (soundCache.has(track.id)) {
      return soundCache.get(track.id) as Sound
    }

    if (soundPromises.has(track.id)) {
      return soundPromises.get(track.id) as Promise<Sound>
    }

    const createSoundPromise = async () => {
      const sources = await getTrackSources(track)
      const { playNext } = useQueue()

      const SoundImplementation = soundImplementation.value
      const sound = new SoundImplementation(sources)

      sound.onSoundEnd(() => {
        console.log('TRACK ENDED, PLAYING NEXT')

        // NOTE: We push it to the end of the job queue
        setTimeout(() => playNext(), 0)
      })

      soundCache.set(track.id, sound)
      soundPromises.delete(track.id)
      return sound
    }

    console.log('NO TRACK IN CACHE, CREATING', track)
    const soundPromise = createSoundPromise()
    soundPromises.set(track.id, soundPromise)
    return soundPromise
  }

  // Preload next track
  const { start: startPreloadTimeout } = useTimeoutFn(async (index) => {
    const { queue } = useQueue()
    const sound = await createSound(queue.value[index as number])
    await sound.preload()
  }, 100, { immediate: false })

  // Create track from queue
  const createTrack = async (index: number) => {
    const { queue, currentIndex, playNext, hasNext } = useQueue()
    if (queue.value.length <= index || index === -1) return
    console.log('LOADING TRACK', index)

    const track = queue.value[index]
    const sound = await createSound(track)

    if (!sound.playable) {
      setTimeout(() => {
        if (hasNext.value && index !== queue.value.length - 1) {
          return playNext(true)
        }

        const { isPlaying } = usePlayer()
        isPlaying.value = false
      }, 3000)
      return
    }

    console.log('CONNECTING NODE')

    sound.audioNode.disconnect()
    connectAudioSource(sound.audioNode)

    const { isPlaying } = usePlayer()
    if (isPlaying.value && index === currentIndex.value) {
      await sound.play()
    }
  }
  
  const currentTrack = ref<QueueTrack>()

  // NOTE: We want to have it called only once, hence we're using createGlobalState
  const initialize = createGlobalState(() => {
    const { currentIndex, currentTrack: track, queue, hasNext } = useQueue()

    whenever(track, () => {
      createTrack(currentIndex.value)
    }, { immediate: true })

    let lastTrack: QueueTrack
    watchEffect(async () => {
      if (!hasNext.value) return

      const nextTrack = queue.value[currentIndex.value + 1]
      if (lastTrack === nextTrack) return
      lastTrack = nextTrack

      // NOTE: Preload next track
      //       Calling this function clears previous timeout and starts a new one.
      //       Since this watchEffect fires whenever currentIndex / nextTrack changes, it will automatically cleanup previous preload.
      // @ts-expect-error vueuse is wrongly typed: https://github.com/vueuse/vueuse/issues/2691
      startPreloadTimeout(currentIndex.value + 1)
    })

    syncRef(track, currentTrack, {
      direction: 'ltr'
    })
  })

  const currentSound = computed(() => soundCache.get(currentTrack.value?.id ?? -1))

  return {
    initialize,
    createSound,
    createTrack,
    currentSound
  }
})
