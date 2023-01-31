<script setup lang="ts">
import { usePlayer } from '~/composables/audio/player'
import { useQueue } from '~/composables/audio/queue'

import { useMouse, useWindowSize } from '@vueuse/core'
import { computed, ref } from 'vue'
import { useStore } from '~/store'
import { useI18n } from 'vue-i18n'

import onKeyboardShortcut from '~/composables/onKeyboardShortcut'
import time from '~/utils/time'

import TrackFavoriteIcon from '~/components/favorites/TrackFavoriteIcon.vue'
import TrackPlaylistIcon from '~/components/playlists/TrackPlaylistIcon.vue'
import PlayerControls from './PlayerControls.vue'
import VolumeControl from './VolumeControl.vue'

const {
  LoopingMode,
  initializeFirstTrack,
  isPlaying,
  mute,
  volume,
  toggleLooping,
  looping,
  seekBy,
  seekTo,
  currentTime,
  duration,
  progress,
  bufferProgress,
  loading: isLoadingAudio
} = usePlayer()

const {
  playPrevious,
  playNext,
  queue,
  currentIndex,
  currentTrack,
  isShuffled,
  shuffle,
  clear
} = useQueue()

const store = useStore()
const { t } = useI18n()

const toggleMobilePlayer = () => {
  store.commit('ui/queueFocused', ['queue', 'player'].includes(store.state.ui.queueFocused as string) ? null : 'player')
}

// Key binds
onKeyboardShortcut('e', toggleMobilePlayer)
onKeyboardShortcut('p', () => { isPlaying.value = !isPlaying.value })
onKeyboardShortcut('s', shuffle)
onKeyboardShortcut('q', clear)
onKeyboardShortcut('m', mute)
onKeyboardShortcut('l', toggleLooping)
onKeyboardShortcut('f', () => store.dispatch('favorites/toggle', currentTrack.value?.id))
onKeyboardShortcut('escape', () => store.commit('ui/queueFocused', null))

onKeyboardShortcut(['shift', 'up'], () => (volume.value += 0.1), true)
onKeyboardShortcut(['shift', 'down'], () => (volume.value -= 0.1), true)

onKeyboardShortcut('right', () => seekBy(5), true)
onKeyboardShortcut(['shift', 'right'], () => seekBy(30), true)
onKeyboardShortcut('left', () => seekBy(-5), true)
onKeyboardShortcut(['shift', 'left'], () => seekBy(-30), true)

onKeyboardShortcut(['ctrl', 'shift', 'left'], playPrevious, true)
onKeyboardShortcut(['ctrl', 'shift', 'right'], playNext, true)

const labels = computed(() => ({
  audioPlayer: t('components.audio.Player.label.audioPlayer'),
  previous: t('components.audio.Player.label.previousTrack'),
  play: t('components.audio.Player.label.play'),
  pause: t('components.audio.Player.label.pause'),
  next: t('components.audio.Player.label.nextTrack'),
  unmute: t('components.audio.Player.label.unmute'),
  mute: t('components.audio.Player.label.mute'),
  expandQueue: t('components.audio.Player.label.expandQueue'),
  shuffle: t('components.audio.Player.label.shuffleQueue'),
  clear: t('components.audio.Player.label.clearQueue'),
  addArtistContentFilter: t('components.audio.Player.label.addArtistContentFilter')
}))

const switchTab = () => {
  store.commit('ui/queueFocused', store.state.ui.queueFocused === 'player' ? 'queue' : 'player')
}

const progressBar = ref()
const touchProgress = (event: MouseEvent) => {
  const time = ((event.clientX - ((event.target as Element).closest('.progress')?.getBoundingClientRect().left ?? 0)) / progressBar.value.offsetWidth) * duration.value
  seekTo(time)
}

const { x } = useMouse({ type: 'client' })
const { width: screenWidth } = useWindowSize({ includeScrollbar: false })

initializeFirstTrack()

const loopingTitle = computed(() => {
  const mode = looping.value
  return mode === LoopingMode.None
    ? t('components.audio.Player.label.loopingDisabled')
    : mode === LoopingMode.LoopTrack
      ? t('components.audio.Player.label.loopingSingle')
      : t('components.audio.Player.label.loopingWholeQueue')
})

const hideArtist = () => {
  if (currentTrack.value.artistId !== -1) {
    return store.dispatch('moderation/hide', {
      type: 'artist',
      target: {
        id: currentTrack.value.artistId,
        name: currentTrack.value.artistName
      }
    })
  }
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
      {{ $t('components.audio.Player.header.player') }}
    </h1>
    <div
      class="ui inverted segment fixed-controls"
      @click.prevent.stop="toggleMobilePlayer"
    >
      <div
        ref="progressBar"
        :class="['ui', 'top attached', 'small', 'inverted', {'indicating': isLoadingAudio}, 'progress']"
        @click.prevent.stop="touchProgress"
      >
        <div
          class="buffer bar"
          :style="{ 'transform': `translateX(${bufferProgress - 100}%)` }"
        />
        <div
          class="position bar"
        />
        <div
          class="seek bar"
          :style="{ 'transform': `translateX(${x / screenWidth * 100 - 100}%)` }"
        />
      </div>
      <div class="controls-row">
        <div class="controls track-controls queue-not-focused desktop-and-up">
          <div
            class="ui tiny image"
            @click.stop.prevent="$router.push({name: 'library.tracks.detail', params: {id: currentTrack.id }})"
          >
            <img
              ref="cover"
              alt=""
              :src="$store.getters['instance/absoluteUrl'](currentTrack.coverUrl)"
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
                :to="{name: 'library.artists.detail', params: {id: currentTrack.artistId }}"
                @click.stop.prevent=""
              >
                {{ currentTrack.artistName ?? $t('components.audio.Player.meta.unknownArtist') }}
              </router-link>
              <template v-if="currentTrack.albumId !== -1">
                <span class="middle slash symbol" />
                <router-link
                  class="discrete link"
                  :to="{name: 'library.albums.detail', params: {id: currentTrack.albumId }}"
                  @click.stop.prevent=""
                >
                  {{ currentTrack.albumTitle ?? $t('components.audio.Player.meta.unknownAlbum') }}
                </router-link>
              </template>
            </div>
          </div>
        </div>
        <div class="controls track-controls queue-not-focused desktop-and-below">
          <div class="ui tiny image">
            <img
              ref="cover"
              alt=""
              :src="$store.getters['instance/absoluteUrl'](currentTrack.coverUrl)"
            >
          </div>
          <div class="middle aligned content ellipsis">
            <strong>
              {{ currentTrack.title }}
            </strong>
            <div class="meta">
              {{ currentTrack.artistName ?? $t('components.audio.Player.meta.unknownArtist') }}
              <template v-if="currentTrack.albumId !== -1">
                <span class="middle slash symbol" />
                {{ currentTrack.albumTitle ?? $t('components.audio.Player.meta.unknownAlbum') }}
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
            @click="hideArtist"
          >
            <i :class="['eye slash outline', 'basic', 'icon']" />
          </button>
        </div>
        <player-controls class="controls queue-not-focused" />
        <div class="controls progress-controls queue-not-focused tablet-and-up small align-left">
          <div class="timer">
            <template v-if="!isLoadingAudio">
              <span
                class="start"
                @click.stop.prevent="seekTo(0)"
              >
                {{ time.parse(Math.round(currentTime)) }}
              </span>
              <span class="middle pipe symbol" />
              <span class="total">{{ time.parse(Math.round(duration)) }}</span>
            </template>
          </div>
        </div>
        <div class="controls queue-controls when-queue-focused align-right">
          <div class="group">
            <volume-control class="expandable" />
            <button
              class="circular control button"
              :class="{ looping: looping !== LoopingMode.None }"
              :title="loopingTitle"
              :aria-label="loopingTitle"
              :disabled="!currentTrack"
              @click.prevent.stop="toggleLooping"
            >
              <i class="repeat icon">
                <span
                  v-if="looping !== LoopingMode.None"
                  class="ui circular tiny vibrant label"
                >
                  <span
                    v-if="looping === LoopingMode.LoopTrack"
                    class="symbol single"
                  />
                  <span
                    v-else-if="looping === LoopingMode.LoopQueue"
                    class="infinity symbol"
                  />
                </span>
              </i>
            </button>

            <button
              class="circular control button"
              :disabled="queue.length === 0"
              :title="labels.shuffle"
              :aria-label="labels.shuffle"
              @click.prevent.stop="shuffle()"
            >
              <i :class="['ui', 'random', { disabled: queue.length === 0, shuffling: isShuffled }, 'icon']" />
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
                <span>
                  {{ $t('components.audio.Player.meta.position', { index: currentIndex + 1, length: queue.length }) }}
                </span>
              </button>
              <button
                class="position circular control button desktop-and-below"
                @click.stop="switchTab"
              >
                <i class="stream icon" />
                <span>
                  {{ $t('components.audio.Player.meta.position', { index: currentIndex + 1, length: queue.length }) }}
                </span>
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
                class="circular control button close-control desktop-and-below"
                @click.stop="switchTab"
              >
                <i class="large up angle icon" />
              </button>
              <button
                v-if="$store.state.ui.queueFocused === 'queue'"
                class="circular control button desktop-and-below"
                @click.stop="switchTab"
              >
                <i class="large down angle icon" />
              </button>
            </div>
            <button
              class="circular control button close-control desktop-and-below"
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
