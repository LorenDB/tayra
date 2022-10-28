import type { QueueTrack, QueueTrackSource } from '~/composables/audio/queue'
import type { Sound } from '~/api/player'

import { soundImplementation } from '~/api/player'
import { createGlobalState, syncRef } from '@vueuse/core'
import { computed, ref, watchEffect } from 'vue'

import { useQueue } from '~/composables/audio/queue'
import { connectAudioSource } from '~/composables/audio/audio-api'
import { usePlayer } from '~/composables/audio/player'

import useLRUCache from '~/composables/useLRUCache'
import store from '~/store'

const ALLOWED_PLAY_TYPES: (CanPlayTypeResult | undefined)[] = ['maybe', 'probably']
const AUDIO_ELEMENT = document.createElement('audio')

const soundPromises = new Map<number, Promise<Sound>>()
const soundCache = useLRUCache<number, Sound>({ max: 10 })

const getTrackSources = (track: QueueTrack): QueueTrackSource[] => {
  const sources: QueueTrackSource[] = track.sources
    // NOTE: Filter out repeating and unplayable media types
    .filter(({ mimetype, bitrate }, index, array) => array.findIndex((upload) => upload.mimetype + upload.bitrate === mimetype + bitrate) === index)
    .filter(({ mimetype }) => ALLOWED_PLAY_TYPES.includes(AUDIO_ELEMENT.canPlayType(`${mimetype}`)))
    .map((source) => ({
      ...source,
      url: store.getters['instance/absoluteUrl'](source.url) as string
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
      const sources = getTrackSources(track)
      const { playNext, currentIndex } = useQueue()

      const SoundImplementation = soundImplementation.value
      const sound = new SoundImplementation(sources)
      sound.onSoundEnd(() => {
        console.log('TRACK ENDED, PLAYING NEXT')
        createTrack(currentIndex.value + 1)

        // NOTE: We push it to the end of the job queue
        setTimeout(playNext, 0)
      })
      soundCache.set(track.id, sound)
      soundPromises.delete(track.id)
      return sound
    }

    const soundPromise = createSoundPromise()
    soundPromises.set(track.id, soundPromise)
    return soundPromise
  }

  // Create track from queue
  const createTrack = async (index: number) => {
    const { queue, currentIndex } = useQueue()
    if (queue.value.length <= index || index === -1) return
    console.log('LOADING TRACK', index)

    const track = queue.value[index]
    if (!soundPromises.has(track.id) && !soundCache.has(track.id)) {
      // TODO (wvffle): Resolve race condition - is it still here after adding soundPromises?
      console.log('NO TRACK IN CACHE, CREATING')
    }

    const sound = await createSound(track)
    console.log('CONNECTING NODE')

    sound.audioNode.disconnect()
    connectAudioSource(sound.audioNode)

    const { isPlaying } = usePlayer()
    if (isPlaying.value && index === currentIndex.value) {
      await sound.play()
    }

    // NOTE: Preload next track
    if (index === currentIndex.value && index + 1 < queue.value.length) {
      setTimeout(async () => {
        const sound = await createSound(queue.value[index + 1])
        await sound.preload()
      }, 100)
    }
  }

  const currentTrack = ref<QueueTrack>()

  // NOTE: We want to have it called only once, hence we're using createGlobalState
  const initialize = createGlobalState(() => {
    const { currentTrack: track, currentIndex } = useQueue()
    watchEffect(async () => createTrack(currentIndex.value))
    syncRef(currentTrack, track)
  })

  const currentSound = computed(() => soundCache.get(currentTrack.value?.id ?? -1))

  return {
    initialize,
    createSound,
    createTrack,
    currentSound
  }
})
