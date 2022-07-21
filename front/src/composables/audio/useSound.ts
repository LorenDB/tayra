import type { Track } from '~/types'

import { ref, computed } from 'vue'
import { Howl } from 'howler'
import useTrackSources from '~/composables/audio/useTrackSources'
import useSoundCache from '~/composables/audio/useSoundCache'
import usePlayer from '~/composables/audio/usePlayer'
import store from '~/store'
import { createEventHook, useThrottleFn } from '@vueuse/core'

interface Sound {
  id?: number
  howl: Howl
  stop: () => void
  play: () => void
  pause: () => void
  state: () => 'unloaded' | 'loading' | 'loaded'
  seek: (time?: number) => number
  duration: () => number
  getSource: () => boolean
  triggerSoundProgress: (time: number, duration: number) => void
}

const soundCache = useSoundCache()
const currentTrack = computed(() => store.getters['queue/currentTrack'])
const looping = computed(() => store.state.player.looping)

const currentSound = ref()
const soundId = ref()

const soundProgress = createEventHook<{ node: HTMLAudioElement, time: number, duration: number }>()

const createSound = (howl: Howl): Sound => ({
  howl,
  play () {
    this.id = howl.play(this.id)
  },
  stop () {
    howl.stop(this.id)
    this.id = undefined
  },
  pause () {
    howl.pause(this.id)
  },
  state: () => howl.state(),
  seek: (time?: number) => howl.seek(time),
  duration: () => howl.duration(),
  getSource: () => (howl as any)._sounds[0],
  triggerSoundProgress: useThrottleFn((time: number, duration: number) => soundProgress.trigger({ node: (howl as any)._sounds[0]._node, time, duration }), 1000)
})

const loadSound = (track: Track): Sound => {
  const cached = soundCache.get(track.id)
  if (cached) {
    return createSound(cached.howl)
  }

  const sources = useTrackSources(track)

  const howl = new Howl({
    src: sources.map((source) => source.url),
    format: sources.map((source) => source.type),
    autoplay: false,
    loop: false,
    html5: true,
    preload: true,

    onend () {
      const onlyTrack = store.state.queue.tracks.length === 1
      if (looping.value === 1 || (onlyTrack && looping.value === 2)) {
        currentSound.value.seek(0)
        store.dispatch('player/updateProgress', 0)
        soundId.value = currentSound.value.play(soundId.value)
      } else {
        store.dispatch('player/trackEnded', currentTrack.value)
      }
    },

    onunlock () {
      if (store.state.player.playing && currentSound.value) {
        soundId.value = currentSound.value.play(soundId.value)
      }
    },

    onload () {
      const node = (howl as any)._sounds[0]._node as HTMLAudioElement

      node.addEventListener('progress', () => {
        if (howl !== currentSound.value) {
          return
        }

        currentSound.value._triggerSoundProgress()
      })
    },

    onplay () {
      const [otherId] = (this as any)._getSoundIds()
      const [currentId] = (currentSound.value?.howl as any)._getSoundIds() ?? []

      if (otherId !== currentId) {
        return (this as any).stop()
      }

      const time = currentSound.value.seek()
      const duration = currentSound.value.duration()
      if (time <= duration / 2) {
        const { isListeningSubmitted } = usePlayer()
        isListeningSubmitted.value = false
      }

      store.commit('player/isLoadingAudio', false)
      store.commit('player/resetErrorCount')
      store.commit('player/errored', false)
      store.commit('player/duration', howl.duration())
    },

    onplayerror (soundId, error) {
      console.error('play error', soundId, error)
    },

    onloaderror (soundId, error) {
      soundCache.delete(track.id)
      howl.unload()

      const [otherId] = (this as any)._getSoundIds()
      const [currentId] = (currentSound.value?.howl as any)._getSoundIds() ?? []

      if (otherId !== currentId) {
        console.error('load error', soundId, error)
        return
      }

      console.error('Error while playing:', soundId, error)
      store.commit('player/isLoadingAudio', false)
      store.dispatch('player/trackErrored')
    }
  })

  soundCache.set(track.id, {
    id: track.id,
    date: new Date(),
    howl
  })

  return createSound(howl)
}

export default () => {
  return {
    loadSound,
    currentSound,
    onSoundProgress: soundProgress.on
  }
}
