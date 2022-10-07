import type { IAudioContext, IMediaElementAudioSourceNode } from 'standardized-audio-context'
import type { Track, Upload } from '~/types'

import { connectAudioSource, createAudioSource } from '~/composables/audio/audio-api'
import { isPlaying } from '~/composables/audio/player'

import useQueue from '~/composables/audio/useQueue'

import { useEventListener } from '@vueuse/core'

import store from '~/store'
import axios from 'axios'

export interface SoundSource {
  uuid: string
  mimetype: string
  url: string
}

export interface Sound {
  audio: HTMLAudioElement
  sources: SoundSource[]
  sourceNode: IMediaElementAudioSourceNode<IAudioContext>
}

const ALLOWED_PLAY_TYPES: (CanPlayTypeResult | undefined)[] = ['maybe', 'probably']
const AUDIO_ELEMENT = document.createElement('audio')

const { tracks, currentIndex } = useQueue()

const soundPromises = new Map<number, Promise<Sound>>()
const soundCache = new Map<number, Sound>()

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

    const audio = new Audio()
    audio.src = sources[0].url

    const sourceNode = createAudioSource(audio)

    const sound = { audio, sources, sourceNode }
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
  if (tracks.value.length <= index || index === -1) return
  console.log('LOADING TRACK')

  const track = tracks.value[index]
  if (!soundPromises.has(track.id) && !soundCache.has(track.id)) {
    // TODO (wvffle): Resolve race condition
    console.log('NO TRACK IN CACHE, CREATING')
  }

  const sound = await createSound(track)
  console.log('CONNECTING NODE')

  const stop = useEventListener(sound.audio, 'ended', () => {
    createTrack(currentIndex.value + 1)
    store.dispatch('queue/next')
    stop()
  })

  sound.sourceNode.disconnect()
  connectAudioSource(sound.sourceNode)

  if (isPlaying.value) {
    sound.audio.play()
  }

  // NOTE: Preload next track
  if (index + 1 < tracks.value.length) {
    createSound(tracks.value[index + 1])
      .then(sound => sound.audio.load())
  }
}

export const getCurrentSound = () => {
  return soundCache.get(tracks.value[currentIndex.value]?.id ?? -1)
}
