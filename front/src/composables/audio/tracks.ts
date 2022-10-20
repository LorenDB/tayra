import type { Sound, SoundSource } from '~/api/player'
import type { Track, Upload } from '~/types'

import { connectAudioSource } from '~/composables/audio/audio-api'
import { isPlaying } from '~/composables/audio/player'
import { soundImplementation } from '~/api/player'
import { computed, shallowReactive } from 'vue'
import { playNext, tracks, currentIndex } from '~/composables/audio/queue'

import store from '~/store'
import axios from 'axios'

const ALLOWED_PLAY_TYPES: (CanPlayTypeResult | undefined)[] = ['maybe', 'probably']
const AUDIO_ELEMENT = document.createElement('audio')

const soundPromises = new Map<number, Promise<Sound>>()
const soundCache = shallowReactive(new Map<number, Sound>())

const getUploadSources = (uploads: Upload[]): SoundSource[] => {
  const sources = uploads
    // NOTE: Filter out repeating and unplayable media types
    .filter(({ mimetype }, index, array) => array.findIndex((upload) => upload.mimetype === mimetype) === index)
    .filter(({ mimetype }) => ALLOWED_PLAY_TYPES.includes(AUDIO_ELEMENT.canPlayType(`${mimetype}`)))
    .map((upload): SoundSource => ({
      ...upload,
      url: store.getters['instance/absoluteUrl'](upload.listen_url) as string
    }))

  // NOTE: Add a transcoded MP3 src at the end for browsers
  //       that do not support other codecs to be able to play it :)
  if (sources.length > 0 && !sources.some(({ mimetype }) => mimetype === 'audio/mpeg')) {
    const url = new URL(sources[0].url)
    url.searchParams.set('to', 'mp3')
    sources.push({ uuid: 'transcoded', mimetype: 'audio/mpeg', url: url.toString() })
  }

  return sources
}

const getTrackSources = async (track: Track): Promise<SoundSource[]> => {
  if (track === undefined) return []

  if (track.uploads.length === 0) {
    // we don't have any information for this track, we need to fetch it
    const { uploads } = await axios.get(`tracks/${track.id}/`)
      .then(response => response.data as Track, () => ({ uploads: [] as Upload[] } as Track))

    track.uploads = uploads
  }

  return getUploadSources(track.uploads)
}

export const createSound = async (track: Track): Promise<Sound> => {
  if (soundCache.has(track.id)) {
    return soundCache.get(track.id) as Sound
  }

  if (soundPromises.has(track.id)) {
    return soundPromises.get(track.id) as Promise<Sound>
  }

  const createSoundPromise = async () => {
    const sources = await getTrackSources(track)

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
export const createTrack = async (index: number) => {
  if (tracks.length <= index || index === -1) return
  console.log('LOADING TRACK')

  const track = tracks[index]
  if (!soundPromises.has(track.id) && !soundCache.has(track.id)) {
    // TODO (wvffle): Resolve race condition - is it still here after adding soundPromises?
    console.log('NO TRACK IN CACHE, CREATING')
  }

  const sound = await createSound(track)
  console.log('CONNECTING NODE')

  sound.audioNode.disconnect()
  connectAudioSource(sound.audioNode)

  if (isPlaying.value) {
    await sound.play()
  }

  // NOTE: Preload next track
  if (index === currentIndex.value && index + 1 < tracks.length) {
    setTimeout(async () => {
      const sound = await createSound(tracks[index + 1])
      await sound.preload()
    }, 100)
  }
}

export const currentSound = computed(() => soundCache.get(tracks[currentIndex.value]?.id ?? -1))
