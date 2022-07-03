<script setup lang="ts">
// TODO (wvffle): Move most of this stufff to usePlayer
import { Track } from '~/types'
import { useStore } from '~/store'
import { Howl, Howler } from 'howler'
import axios from 'axios'
import VolumeControl from './VolumeControl.vue'
import TrackFavoriteIcon from '~/components/favorites/TrackFavoriteIcon.vue'
import TrackPlaylistIcon from '~/components/playlists/TrackPlaylistIcon.vue'
import onKeyboardShortcut from '~/composables/onKeyboardShortcut'
import { ref, computed, watch, onMounted, onBeforeUnmount, watchEffect } from 'vue'
import { useTimeoutFn, useIntervalFn } from '@vueuse/core'
import { useGettext } from 'vue3-gettext'
import useQueue from '~/composables/audio/useQueue'
import usePlayer from '~/composables/audio/usePlayer'
import useTrackSources, { TrackSource } from '~/composables/audio/useTrackSources'
import useSoundCache from '~/composables/audio/useSoundCache'

const store = useStore()
const { $pgettext } = useGettext()

const toggleMobilePlayer = () => {
  store.commit('ui/queueFocused', ['queue', 'player'].includes(store.state.ui.queueFocused as string) ? null : 'player')
}

const {
  isShuffling,
  shuffle,
  previous,
  isEmpty: queueIsEmpty,
  hasNext,
  hasPrevious,
  currentTrack,
  currentIndex,
  tracks,
  next
} = useQueue()

const {
  playing,
  loading: isLoadingAudio,
  looping,
  duration,
  progress,
  durationFormatted,
  currentTimeFormatted,
  bufferProgress,
  currentTime,
  seek,
  togglePlayback,
  resume,
  pause
} = usePlayer()

// Key binds
onKeyboardShortcut('e', toggleMobilePlayer)
onKeyboardShortcut('p', togglePlayback)
onKeyboardShortcut('s', shuffle)
onKeyboardShortcut('q', () => store.dispatch('queue/clean'))
onKeyboardShortcut('m', () => store.dispatch('player/toggleMute'))
onKeyboardShortcut('l', () => store.commit('player/toggleLooping'))
onKeyboardShortcut('f', () => store.dispatch('favorites/toggle', currentTrack.value?.id))
onKeyboardShortcut('escape', () => store.commit('ui/queueFocused', null))

onKeyboardShortcut(['shift', 'up'], () => store.commit('player/incrementVolume', 0.1), true)
onKeyboardShortcut(['shift', 'down'], () => store.commit('player/incrementVolume', -0.1), true)

onKeyboardShortcut('right', () => seek(5), true)
onKeyboardShortcut(['shift', 'right'], () => seek(30), true)
onKeyboardShortcut('left', () => seek(-5), true)
onKeyboardShortcut(['shift', 'left'], () => seek(-30), true)

onKeyboardShortcut(['ctrl', 'shift', 'left'], previous, true)
onKeyboardShortcut(['ctrl', 'shift', 'right'], next, true)

const currentSound = ref()
const isUpdatingTime = ref(false)
const preloadDelay = ref(15)
const isListeningSubmitted = ref()
const soundId = ref()
const nextTrackPreloaded = ref(false)

const maxPreloaded = ref(3)
const soundCache = useSoundCache(maxPreloaded)

const updateProgress = () => {
  isUpdatingTime.value = true

  if (currentSound.value?.state() === 'loaded') {
    const time = currentSound.value.seek()
    const duration = currentSound.value.duration()

    store.dispatch('player/updateProgress', time)
    updateBuffer(currentSound.value._sounds[0]._node)

    const toPreload = store.state.queue.tracks[currentIndex.value + 1]
    if (!nextTrackPreloaded.value && toPreload && !soundCache.has(toPreload.id) && (time > preloadDelay.value || duration - time < 30)) {
      getSound(toPreload)
      nextTrackPreloaded.value = true
    }

    if (time > duration / 2) {
      if (!isListeningSubmitted.value) {
        store.dispatch('player/trackListened', currentTrack.value)
        isListeningSubmitted.value = true
      }
    }
  }
}

// const updateProgressThrottled = useThrottleFn(updateProgress, 50)

const labels = computed(() => ({
  audioPlayer: $pgettext('Sidebar/Player/Hidden text', 'Media player'),
  previous: $pgettext('Sidebar/Player/Icon.Tooltip', 'Previous track'),
  play: $pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Play'),
  pause: $pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Pause'),
  next: $pgettext('Sidebar/Player/Icon.Tooltip', 'Next track'),
  unmute: $pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Unmute'),
  mute: $pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Mute'),
  expandQueue: $pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Expand queue'),
  loopingDisabled: $pgettext('Sidebar/Player/Icon.Tooltip', 'Looping disabled. Click to switch to single-track looping.'),
  loopingSingle: $pgettext('Sidebar/Player/Icon.Tooltip', 'Looping on a single track. Click to switch to whole queue looping.'),
  loopingWhole: $pgettext('Sidebar/Player/Icon.Tooltip', 'Looping on whole queue. Click to disable looping.'),
  shuffle: $pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Shuffle your queue'),
  clear: $pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Clear your queue'),
  addArtistContentFilter: $pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Hide content from this artist…')
}))

// Preloading
const { start: loadCurrentTrack, stop: cancelLoadingCurrentTrack } = useTimeoutFn(
  (track, oldValue) => loadSound(track as Track, oldValue as Track),
  100,
  { immediate: false }
) as { start: (a: Track, b: Track) => unknown, stop: () => void }

watch(currentTrack, (track, oldValue) => {
  nextTrackPreloaded.value = false

  cancelLoadingCurrentTrack()

  currentSound.value?.pause()
  store.commit('player/isLoadingAudio', true)

  loadCurrentTrack(track, oldValue)
})

const observeProgress = ref(false)
useIntervalFn(() => observeProgress.value && updateProgress(), 1000)

watch(playing, async (isPlaying) => {
  if (currentSound.value) {
    if (isPlaying) {
      soundId.value = currentSound.value.play(soundId.value)
    } else {
      currentSound.value.pause(soundId.value)
    }
  } else {
    await loadSound(currentTrack.value)
  }

  observeProgress.value = isPlaying
})

const setCurrentTime = (time: number) => {
  if (time < 0 || time > duration.value) {
    return
  }

  if (!currentSound.value?._sounds[0] || time === currentSound.value.seek()) {
    return
  }

  // if (time === 0) {
  //   this.updateProgressThrottled.cancel()
  // }

  currentSound.value.seek(time)
  // If player is paused update progress immediately to ensure updated UI
  if (!playing.value) {
    updateProgress()
  }
}

watchEffect(() => {
  if (!isUpdatingTime.value) {
    setCurrentTime(currentTime.value)
    isUpdatingTime.value = false
  }
})

onMounted(() => {
  // TODO (wvffle): Check if it is needed
  store.dispatch('player/updateProgress', 0)
  // TODO (wvffle): Check if it is needed
  store.commit('player/playing', false)
  // TODO (wvffle): Check if it is needed
  store.commit('player/isLoadingAudio', false)

  // TODO (wvffle): Check if it is needed
  Howler.unload() // clear existing cache, if any

  // TODO (wvffle): Check if it is needed
  nextTrackPreloaded.value = false

  // Cache sound if we have currentTrack available
  if (currentTrack.value) {
    getSound(currentTrack.value)
  }
})

onBeforeUnmount(() => {
  observeProgress.value = false
})

const getSound = (trackData: Track) => {
  const cached = soundCache.get(trackData.id)
  if (cached) {
    return cached.sound
  }

  const srcs: TrackSource[] = useTrackSources(trackData)
  const sound: Howl = new Howl({
    src: srcs.map((source) => source.url),
    format: srcs.map((source) => source.type),
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
      const node = (sound as any)._sounds[0]._node as HTMLAudioElement

      node.addEventListener('progress', () => {
        if (sound !== currentSound.value) {
          return
        }

        updateBuffer(node)
      })
    },

    onplay () {
      if (this !== currentSound.value) {
        return (this as any).stop()
      }

      const time = currentSound.value.seek()
      const duration = currentSound.value.duration()
      if (time <= duration / 2) {
        isListeningSubmitted.value = false
      }

      store.commit('player/isLoadingAudio', false)
      store.commit('player/resetErrorCount')
      store.commit('player/errored', false)
      store.commit('player/duration', sound.duration())
    },

    onplayerror (soundId, error) {
      console.log('play error', soundId, error)
    },

    onloaderror (soundId, error) {
      console.log('load error', soundId, error)
      soundCache.delete(trackData.id)
      sound.unload()

      if (this !== currentSound.value) {
        return
      }

      console.error('Error while playing:', soundId, error)
      handleError()
    }
  })

  soundCache.set(trackData.id, {
    id: trackData.id,
    date: new Date(),
    sound
  })

  return sound
}

const getTrack = async (trackData: Track) => {
  // use previously fetched trackData
  if (trackData.uploads.length) {
    return trackData
  }

  // we don't have any information for this track, we need to fetch it
  return axios.get(`tracks/${trackData.id}/`)
    .then(response => response.data, () => null)
}

const handleError = () => {
  store.commit('player/isLoadingAudio', false)
  store.dispatch('player/trackErrored')
}

const updateBuffer = (node: HTMLAudioElement) => {
  // from https://github.com/goldfire/howler.js/issues/752#issuecomment-372083163

  const { buffered, currentTime: time } = node

  let range = 0
  try {
    while (buffered.start(range) >= time || time >= buffered.end(range)) {
      range += 1
    }
  } catch (IndexSizeError) {
    return
  }

  let loadPercentage

  const start = buffered.start(range)
  const end = buffered.end(range)

  if (range === 0) {
    // easy case, no user-seek
    const loadStartPercentage = start / node.duration
    const loadEndPercentage = end / node.duration
    loadPercentage = loadEndPercentage - loadStartPercentage
  } else {
    const loaded = end - start
    const remainingToLoad = node.duration - start
    // user seeked a specific position in the audio, our progress must be
    // computed based on the remaining portion of the track
    loadPercentage = loaded / remainingToLoad
  }

  if (loadPercentage * 100 === bufferProgress.value) {
    return
  }

  store.commit('player/bufferProgress', loadPercentage * 100)
}

const loadSound = async (trackData: Track, oldValue?: Track) => {
  const oldSound = currentSound.value

  if (oldSound && trackData !== oldValue) {
    oldSound.stop(soundId.value)
    soundId.value = null
  }

  if (!trackData) {
    return
  }

  if (!isShuffling.value && trackData !== oldValue) {
    trackData = await getTrack(trackData)

    if (trackData == null) {
      handleError()
    }

    currentSound.value = getSound(trackData)

    // TODO (wvffle): #1777
    soundId.value = currentSound.value.play()
    store.commit('player/isLoadingAudio', true)
    store.commit('player/errored', false)
    store.commit('player/playing', true)
    store.dispatch('player/updateProgress', 0)
    observeProgress.value = true
  }
}

const switchTab = () => {
  store.commit('ui/queueFocused', store.state.ui.queueFocused === 'player' ? 'queue' : 'player')
}
</script>

<template>
  <section
    v-if="currentTrack"
    role="complementary"
    class="player-wrapper ui bottom-player component-player"
    aria-labelledby="player-label"
  >
    <h1
      id="player-label"
      class="visually-hidden"
    >
      <translate translate-context="*/*/*">
        Audio player and controls
      </translate>
    </h1>
    <div
      class="ui inverted segment fixed-controls"
      @click.prevent.stop="toggleMobilePlayer"
    >
      <div
        :class="['ui', 'top attached', 'small', 'inverted', {'indicating': isLoadingAudio}, 'progress']"
      >
        <div
          class="buffer bar"
          :data-percent="bufferProgress"
          :style="{ 'width': bufferProgress + '%' }"
        />
        <div
          class="position bar"
          :data-percent="progress"
          :style="{ 'width': progress + '%' }"
        />
      </div>
      <div class="controls-row">
        <div class="controls track-controls queue-not-focused desktop-and-up">
          <div
            class="ui tiny image"
            @click.stop.prevent="$router.push({name: 'library.tracks.detail', params: {id: currentTrack.id }})"
          >
            <img
              v-if="currentTrack.cover && currentTrack.cover.urls.original"
              ref="cover"
              alt=""
              :src="$store.getters['instance/absoluteUrl'](currentTrack.cover.urls.medium_square_crop)"
            >
            <img
              v-else-if="currentTrack.album && currentTrack.album.cover && currentTrack.album.cover.urls && currentTrack.album.cover.urls.original"
              ref="cover"
              alt=""
              :src="$store.getters['instance/absoluteUrl'](currentTrack.album.cover.urls.medium_square_crop)"
            >
            <img
              v-else
              alt=""
              src="../../assets/audio/default-cover.png"
            >
          </div>
          <div
            class="middle aligned content ellipsis"
            @click.stop.prevent=""
          >
            <strong>
              <router-link
                class="small header discrete link track"
                :to="{name: 'library.tracks.detail', params: {id: currentTrack.id }}"
                @click.stop.prevent=""
              >
                {{ currentTrack.title }}
              </router-link>
            </strong>
            <div class="meta">
              <router-link
                class="discrete link"
                :to="{name: 'library.artists.detail', params: {id: currentTrack.artist.id }}"
                @click.stop.prevent=""
              >
                {{ currentTrack.artist.name }}
              </router-link>
              <template v-if="currentTrack.album">
                /
                <router-link
                  class="discrete link"
                  :to="{name: 'library.albums.detail', params: {id: currentTrack.album.id }}"
                  @click.stop.prevent=""
                >
                  {{ currentTrack.album.title }}
                </router-link>
              </template>
            </div>
          </div>
        </div>
        <div class="controls track-controls queue-not-focused tablet-and-below">
          <div class="ui tiny image">
            <img
              v-if="currentTrack.cover && currentTrack.cover.urls.original"
              ref="cover"
              alt=""
              :src="$store.getters['instance/absoluteUrl'](currentTrack.cover.urls.medium_square_crop)"
            >
            <img
              v-else-if="currentTrack.album && currentTrack.album.cover && currentTrack.album.cover.urls.original"
              ref="cover"
              alt=""
              :src="$store.getters['instance/absoluteUrl'](currentTrack.album.cover.urls.medium_square_crop)"
            >
            <img
              v-else
              alt=""
              src="../../assets/audio/default-cover.png"
            >
          </div>
          <div class="middle aligned content ellipsis">
            <strong>
              {{ currentTrack.title }}
            </strong>
            <div class="meta">
              {{ currentTrack.artist.name }}<template v-if="currentTrack.album">
                / {{ currentTrack.album.title }}
              </template>
            </div>
          </div>
        </div>
        <div
          v-if="$store.state.auth.authenticated"
          class="controls desktop-and-up fluid align-right"
        >
          <track-favorite-icon
            class="control white"
            :track="currentTrack"
          />
          <track-playlist-icon
            class="control white"
            :track="currentTrack"
          />
          <button
            :class="['ui', 'really', 'basic', 'circular', 'icon', 'button', 'control']"
            :aria-label="labels.addArtistContentFilter"
            :title="labels.addArtistContentFilter"
            @click="$store.dispatch('moderation/hide', {type: 'artist', target: currentTrack.artist})"
          >
            <i :class="['eye slash outline', 'basic', 'icon']" />
          </button>
        </div>
        <div class="player-controls controls queue-not-focused">
          <button
            :title="labels.previous"
            :aria-label="labels.previous"
            :disabled="!hasPrevious"
            class="circular button control tablet-and-up"
            @click.prevent.stop="$store.dispatch('queue/previous')"
          >
            <i :class="['ui', 'large', {'disabled': !hasPrevious}, 'backward step', 'icon']" />
          </button>
          <button
            v-if="!playing"
            :title="labels.play"
            :aria-label="labels.play"
            class="circular button control"
            @click.prevent.stop="resume"
          >
            <i :class="['ui', 'big', 'play', {'disabled': !currentTrack}, 'icon']" />
          </button>
          <button
            v-else
            :title="labels.pause"
            :aria-label="labels.pause"
            class="circular button control"
            @click.prevent.stop="pause"
          >
            <i :class="['ui', 'big', 'pause', {'disabled': !currentTrack}, 'icon']" />
          </button>
          <button
            :title="labels.next"
            :aria-label="labels.next"
            :disabled="!hasNext"
            class="circular button control"
            @click.prevent.stop="$store.dispatch('queue/next')"
          >
            <i :class="['ui', 'large', {'disabled': !hasNext}, 'forward step', 'icon']" />
          </button>
        </div>

        <div class="controls progress-controls queue-not-focused tablet-and-up small align-left">
          <div class="timer">
            <template v-if="!isLoadingAudio">
              <span
                class="start"
                @click.stop.prevent="setCurrentTime(0)"
              >
                {{ currentTimeFormatted }}
              </span>
              | 
              <span class="total">{{ durationFormatted }}</span>
            </template>
          </div>
        </div>
        <div class="controls queue-controls when-queue-focused align-right">
          <div class="group">
            <volume-control class="expandable" />
            <button
              v-if="looping === 0"
              class="circular control button"
              :title="labels.loopingDisabled"
              :aria-label="labels.loopingDisabled"
              :disabled="!currentTrack"
              @click.prevent.stop="$store.commit('player/looping', 1)"
            >
              <i :class="['ui', {'disabled': !currentTrack}, 'step', 'repeat', 'icon']" />
            </button>
            <button
              v-if="looping === 1"
              :title="labels.loopingSingle"
              :aria-label="labels.loopingSingle"
              :disabled="!currentTrack"
              class="looping circular control button"
              @click.prevent.stop="$store.commit('player/looping', 2)"
            >
              <i
                class="repeat icon"
              >
                <span class="ui circular tiny vibrant label">1</span>
              </i>
            </button>
            <button
              v-if="looping === 2"
              class="looping circular control button"
              :title="labels.loopingWhole"
              :aria-label="labels.loopingWhole"
              :disabled="!currentTrack"
              @click.prevent.stop="$store.commit('player/looping', 0)"
            >
              <i
                class="repeat icon"
              >
                <span class="ui circular tiny vibrant label">&infin;</span>
              </i>
            </button>
            <button
              class="circular control button"
              :disabled="queueIsEmpty || null"
              :title="labels.shuffle"
              :aria-label="labels.shuffle"
              @click.prevent.stop="shuffle()"
            >
              <div
                v-if="isShuffling"
                class="ui inline shuffling inverted tiny active loader"
              />
              <i
                v-else
                :class="['ui', 'random', {'disabled': queueIsEmpty}, 'icon']"
              />
            </button>
          </div>
          <div class="group">
            <div class="fake-dropdown">
              <button
                class="position circular control button desktop-and-up"
                aria-expanded="true"
                @click.stop="toggleMobilePlayer"
              >
                <i class="stream icon" />
                <translate
                  translate-context="Sidebar/Queue/Text"
                  :translate-params="{index: currentIndex + 1, length: tracks.length}"
                >
                  %{ index } of %{ length }
                </translate>
              </button>
              <button
                class="position circular control button tablet-and-below"
                @click.stop="switchTab"
              >
                <i class="stream icon" />
                <translate
                  translate-context="Sidebar/Queue/Text"
                  :translate-params="{index: currentIndex + 1, length: tracks.length}"
                >
                  %{ index } of %{ length }
                </translate>
              </button>

              <button
                v-if="$store.state.ui.queueFocused"
                class="circular control button close-control desktop-and-up"
                @click.stop="toggleMobilePlayer"
              >
                <i class="large down angle icon" />
              </button>
              <button
                v-else
                class="circular control button desktop-and-up"
                @click.stop="toggleMobilePlayer"
              >
                <i class="large up angle icon" />
              </button>
              <button
                v-if="$store.state.ui.queueFocused === 'player'"
                class="circular control button close-control tablet-and-below"
                @click.stop="switchTab"
              >
                <i class="large up angle icon" />
              </button>
              <button
                v-if="$store.state.ui.queueFocused === 'queue'"
                class="circular control button tablet-and-below"
                @click.stop="switchTab"
              >
                <i class="large down angle icon" />
              </button>
            </div>
            <button
              class="circular control button close-control tablet-and-below"
              @click.stop="$store.commit('ui/queueFocused', null)"
            >
              <i class="x icon" />
            </button>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>
