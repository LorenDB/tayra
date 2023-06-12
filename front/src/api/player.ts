import type { IAudioContext, IAudioNode } from 'standardized-audio-context'

import { createEventHook, refDefault, type EventHookOn, useEventListener } from '@vueuse/core'
import { createAudioSource } from '~/composables/audio/audio-api'
import { effectScope, reactive, ref, type Ref } from 'vue'

export interface SoundSource {
  uuid: string
  mimetype: string
  url: string
}

export interface Sound {
  preload(): Promise<void>
  dispose(): Promise<void>

  readonly audioNode: IAudioNode<IAudioContext>
  readonly isErrored: Ref<boolean>
  readonly isLoaded: Ref<boolean>
  readonly isDisposed: Ref<boolean>
  readonly currentTime: number
  readonly playable: boolean
  readonly duration: number
  readonly buffered: number
  looping: boolean

  pause(): Promise<void>
  play(): Promise<void>

  seekTo(seconds: number): Promise<void>
  seekBy(seconds: number): Promise<void>

  onSoundLoop: EventHookOn<Sound>
  onSoundEnd: EventHookOn<Sound>
}

export const soundImplementations = reactive(new Set<Constructor<Sound>>())

export const registerSoundImplementation = <T extends Constructor<Sound>>(implementation: T) => {
  soundImplementations.add(implementation)
  return implementation
}

// Default Sound implementation
@registerSoundImplementation
export class HTMLSound implements Sound {
  #audio = new Audio()
  #soundLoopEventHook = createEventHook<HTMLSound>()
  #soundEndEventHook = createEventHook<HTMLSound>()
  #ignoreError = false
  #scope = effectScope()

  readonly isErrored = ref(false)
  readonly isLoaded = ref(false)
  readonly isDisposed = ref(false)

  audioNode = createAudioSource(this.#audio)
  onSoundLoop: EventHookOn<HTMLSound>
  onSoundEnd: EventHookOn<HTMLSound>

  constructor (sources: SoundSource[]) {
    this.onSoundLoop = this.#soundLoopEventHook.on
    this.onSoundEnd = this.#soundEndEventHook.on

    // TODO: Quality picker
    const source = sources[0]?.url
    if (!source) {
      this.isLoaded.value = true
      return
    }

    this.#audio.crossOrigin = 'anonymous'
    this.#audio.src = source
    this.#audio.preload = 'auto'

    console.log('CREATED SOUND INSTANCE', this)

    this.#scope.run(() => {
      useEventListener(this.#audio, 'ended', () => this.#soundEndEventHook.trigger(this))
      useEventListener(this.#audio, 'timeupdate', () => {
        if (this.#audio.currentTime === 0) {
          this.#soundLoopEventHook.trigger(this)
        }
      })

      useEventListener(this.#audio, 'waiting', () => {
        console.log('>> AUDIO WAITING', this)
      })

      useEventListener(this.#audio, 'playing', () => {
        console.log('>> AUDIO PLAYING', this)
      })

      useEventListener(this.#audio, 'stalled', () => {
        console.log('>> AUDIO STALLED', this)
      })

      useEventListener(this.#audio, 'suspend', () => {
        console.log('>> AUDIO SUSPEND', this)
      })

      useEventListener(this.#audio, 'loadeddata', () => {
        // https://developer.mozilla.org/en-US/docs/Web/API/HTMLMediaElement/readyState
        this.isLoaded.value = this.#audio.readyState >= 2
      })

      useEventListener(this.#audio, 'error', (err) => {
        if (this.#ignoreError) return
        console.error('>> AUDIO ERRORED', err, this)
        this.isErrored.value = true
        this.isLoaded.value = true
      })
    })
  }

  async preload () {
    this.isDisposed.value = false
    this.isErrored.value = false
    console.log('CALLING PRELOAD ON', this)
    this.#audio.load()
  }

  async dispose () {
    if (this.isDisposed.value) return

    // Remove all event listeners
    this.#scope.stop()

    // Stop audio playback
    this.audioNode.disconnect()
    this.#audio.pause()

    // Cancel any request downloading the source
    this.#audio.src = ''
    this.#audio.load()

    this.isDisposed.value = true
  }

  async play () {
    try {
      await this.#audio.play()
    } catch (err) {
      console.error('>> AUDIO PLAY ERROR', err, this)
      this.isErrored.value = true
    }
  }

  async pause () {
    return this.#audio.pause()
  }

  async seekTo (seconds: number) {
    this.#audio.currentTime = seconds
  }

  async seekBy (seconds: number) {
    this.#audio.currentTime += seconds
  }

  get playable () {
    return this.#audio.src !== '' || this.isErrored.value
  }

  get duration () {
    const { duration } = this.#audio
    return isNaN(duration) ? 0 : duration
  }

  get buffered () {
    // https://developer.mozilla.org/en-US/docs/Web/Guide/Audio_and_video_delivery/buffering_seeking_time_ranges#creating_our_own_buffering_feedback
    if (this.duration > 0) {
      const { length } = this.#audio.buffered
      for (let i = 0; i < length; i++) {
        if (this.#audio.buffered.start(length - 1 - i) < this.#audio.currentTime) {
          return this.#audio.buffered.end(length - 1 - i)
        }
      }
    }

    return 0
  }

  get currentTime () {
    return this.#audio.currentTime
  }

  get looping () {
    return this.#audio.loop
  }

  set looping (value: boolean) {
    this.#audio.loop = value
  }
}

export const soundImplementation = refDefault(ref<Constructor<Sound>>(), HTMLSound)
