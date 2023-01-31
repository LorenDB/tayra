<script setup lang="ts">
import type { QueueItemSource } from '~/types'

import { whenever, watchDebounced, useCurrentElement, useScrollLock, useFullscreen, useIdle, refAutoReset, useStorage } from '@vueuse/core'
import { nextTick, ref, computed, watchEffect, watch, defineAsyncComponent } from 'vue'
import { useFocusTrap } from '@vueuse/integrations/useFocusTrap'
import { useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { useStore } from '~/store'

import { usePlayer } from '~/composables/audio/player'
import { useTracks } from '~/composables/audio/tracks'
import { useQueue } from '~/composables/audio/queue'

import time from '~/utils/time'

import TrackFavoriteIcon from '~/components/favorites/TrackFavoriteIcon.vue'
import TrackPlaylistIcon from '~/components/playlists/TrackPlaylistIcon.vue'
import PlayerControls from '~/components/audio/PlayerControls.vue'

import VirtualList from '~/components/vui/list/VirtualList.vue'
import QueueItem from '~/components/QueueItem.vue'

const MilkDrop = defineAsyncComponent(() => import('~/components/audio/visualizer/MilkDrop.vue'))

const {
  isPlaying,
  currentTime,
  duration,
  progress,
  bufferProgress,
  seekTo,
  loading: isLoadingAudio,
  errored
} = usePlayer()

const {
  hasNext,
  currentTrack,
  currentIndex,
  queue,
  dequeue,
  playTrack,
  reorder,
  endsIn,
  clear
} = useQueue()

const { currentSound } = useTracks()

const queueModal = ref()
const { activate, deactivate } = useFocusTrap(queueModal, { allowOutsideClick: true, preventScroll: true })

const { t } = useI18n()
const scrollLock = useScrollLock(document.body)
const store = useStore()

const labels = computed(() => ({
  queue: t('components.Queue.label.queue'),
  populating: t('components.Queue.label.populatingRadio'),
  duration: t('components.Queue.label.duration'),
  addArtistContentFilter: t('components.Queue.label.addArtistContentFilter'),
  restart: t('components.Queue.label.restart'),
  previous: t('components.Queue.label.previous'),
  next: t('components.Queue.label.next'),
  pause: t('components.Queue.label.pause'),
  play: t('components.Queue.label.play'),
  fullscreen: t('components.Queue.label.enterFullscreen'),
  exitFullscreen: t('components.Queue.label.exitFullscreen'),
  showCoverArt: t('components.Queue.label.showCoverArt'),
  showVisualizer: t('components.Queue.label.showVisualizer')
}))

watchEffect(async () => {
  scrollLock.value = !!store.state.ui.queueFocused
  if (store.state.ui.queueFocused) {
    await nextTick()
    activate()
  } else {
    deactivate()
  }
})

const list = ref()
const el = useCurrentElement()
const scrollToCurrent = (behavior: ScrollBehavior = 'smooth') => {
  const item = el.value?.querySelector('.queue-item.active')
  item?.scrollIntoView({
    behavior,
    block: 'center'
  })
}

watchDebounced(currentTrack, () => scrollToCurrent(), { debounce: 100 })

whenever(
  () => queue.value.length === 0,
  () => store.commit('ui/queueFocused', null),
  { immediate: true }
)

const router = useRouter()
router.beforeEach(() => store.commit('ui/queueFocused', null))

const progressBar = ref()
const touchProgress = (event: MouseEvent) => {
  const time = ((event.clientX - ((event.target as Element).closest('.progress')?.getBoundingClientRect().left ?? 0)) / progressBar.value.offsetWidth) * duration.value
  seekTo(time)
}

const animated = ref(false)
watch(currentTrack, async track => {
  animated.value = false
  await nextTick()
  animated.value = true
})

const play = async (index: number) => {
  isPlaying.value = true
  return playTrack(index)
}

const queueItems = computed(() => queue.value.map((track, index) => ({
  ...track,
  key: `${index}-${track.id}`,
  labels: {
    remove: t('components.Queue.label.remove'),
    selectTrack: t('components.Queue.label.selectTrack'),
    favorite: t('components.Queue.label.favorite')
  }
}) as QueueItemSource))

const reorderTracks = async (from: number, to: number) => {
  reorder(from, to)

  await nextTick()
  if (to === currentIndex.value) {
    scrollToCurrent()
  }
}

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

const cover = ref()
const { isFullscreen: fullscreen, enter, exit } = useFullscreen(cover)
const { idle } = useIdle(2000)

const showTrackInfo = refAutoReset(false, 5000)
whenever(currentTrack, () => (showTrackInfo.value = true))

const milkdrop = ref()
const loadRandomPreset = () => {
  milkdrop.value?.loadRandomPreset()
}

enum CoverType {
  COVER_ART,
  MILK_DROP
}

const coverType = useStorage('queue:cover-type', CoverType.COVER_ART)
</script>

<template>
  <section
    class="main with-background component-queue"
    :aria-label="labels.queue"
  >
    <div
      id="queue-grid"
      :class="store.state.ui.queueFocused && `show-${store.state.ui.queueFocused}`"
    >
      <div
        id="player"
        class="ui basic segment"
      >
        <template v-if="currentTrack">
          <div
            ref="cover"
            :class="['cover-container', { idle, fullscreen }]"
          >
            <div class="cover">
              <template v-if="coverType === CoverType.COVER_ART">
                <img
                  v-if="fullscreen"
                  class="cover-shadow"
                  :src="$store.getters['instance/absoluteUrl'](currentTrack.coverUrl)"
                >
                <img
                  ref="cover"
                  alt=""
                  :src="$store.getters['instance/absoluteUrl'](currentTrack.coverUrl)"
                >
              </template>
              <milk-drop
                v-else-if="coverType === CoverType.MILK_DROP"
                ref="milkdrop"
              />

              <Transition name="queue">
                <div
                  v-if="!fullscreen || !idle"
                  class="cover-buttons"
                >
                  <button
                    v-if="coverType === CoverType.COVER_ART"
                    class="ui secondary button"
                    :aria-label="labels.showVisualizer"
                    :title="labels.showVisualizer"
                    @click="coverType = CoverType.MILK_DROP"
                  >
                    <i class="icon signal" />
                  </button>
                  <button
                    v-else-if="coverType === CoverType.MILK_DROP"
                    class="ui secondary button"
                    :aria-label="labels.showCoverArt"
                    :title="labels.showCoverArt"
                    @click="coverType = CoverType.COVER_ART"
                  >
                    <i class="icon image outline" />
                  </button>

                  <button
                    v-if="!fullscreen"
                    class="ui secondary button"
                    :aria-label="labels.fullscreen"
                    :title="labels.fullscreen"
                    @click="enter"
                  >
                    <i class="icon expand" />
                  </button>
                  <button
                    v-else
                    class="ui secondary button"
                    :aria-label="labels.exitFullscreen"
                    :title="labels.exitFullscreen"
                    @click="exit"
                  >
                    <i class="icon compress" />
                  </button>
                </div>
              </Transition>
              <Transition name="queue">
                <div
                  v-if="fullscreen && (!idle || showTrackInfo)"
                  class="track-info"
                  @click="loadRandomPreset()"
                >
                  <h1>{{ currentTrack.title }}</h1>
                  <h2>
                    {{ currentTrack.artistName ?? $t('components.Queue.meta.unknownArtist') }}
                    <span class="symbol hyphen middle" />
                    {{ currentTrack.albumTitle ?? $t('components.Queue.meta.unknownAlbum') }}
                  </h2>
                </div>
              </Transition>
            </div>
          </div>
          <h1 class="ui header">
            <div class="content ellipsis">
              <router-link
                class="small header discrete link track"
                :to="{name: 'library.tracks.detail', params: {id: currentTrack.id }}"
              >
                {{ currentTrack.title }}
              </router-link>
              <div class="sub header ellipsis">
                <router-link
                  class="discrete link artist"
                  :to="{name: 'library.artists.detail', params: {id: currentTrack.artistId }}"
                >
                  {{ currentTrack.artistName ?? $t('components.Queue.meta.unknownArtist') }}
                </router-link>
                <template v-if="currentTrack.albumId !== -1">
                  <span class="middle slash symbol" />
                  <router-link
                    class="discrete link album"
                    :to="{name: 'library.albums.detail', params: {id: currentTrack.albumId }}"
                  >
                    {{ currentTrack.albumTitle ?? $t('components.Queue.meta.unknownAlbum') }}
                  </router-link>
                </template>
              </div>
            </div>
          </h1>
          <div
            v-if="currentTrack && errored"
            class="ui small warning message"
          >
            <h3 class="header">
              {{ $t('components.Queue.header.failure') }}
            </h3>
            <p v-if="hasNext && isPlaying">
              {{ $t('components.Queue.message.automaticPlay') }}
              <i class="loading spinner icon" />
            </p>
            <p>
              {{ $t('components.Queue.warning.connectivity') }}
            </p>
          </div>
          <div
            v-else-if="currentSound && !currentSound.playable"
            class="ui small warning message"
          >
            <h3 class="header">
              {{ $t('components.Queue.header.noSources') }}
            </h3>
            <p v-if="hasNext && isPlaying">
              {{ $t('components.Queue.message.automaticPlay') }}
              <i class="loading spinner icon" />
            </p>
          </div>
          <div class="additional-controls desktop-and-below">
            <track-favorite-icon
              v-if="$store.state.auth.authenticated"
              :track="currentTrack"
            />
            <track-playlist-icon
              v-if="$store.state.auth.authenticated"
              :track="currentTrack"
            />
            <button
              v-if="$store.state.auth.authenticated"
              :class="['ui', 'really', 'basic', 'circular', 'icon', 'button']"
              :aria-label="labels.addArtistContentFilter"
              :title="labels.addArtistContentFilter"
              @click="hideArtist"
            >
              <i :class="['eye slash outline', 'basic', 'icon']" />
            </button>
          </div>
          <div class="progress-wrapper">
            <div
              v-if="currentTrack && !errored"
              class="progress-area"
            >
              <div
                ref="progressBar"
                :class="['ui', 'small', 'vibrant', {'indicating': isLoadingAudio}, 'progress']"
                @click="touchProgress"
              >
                <div
                  class="buffer bar"
                  :style="{ 'transform': `translateX(${bufferProgress - 100}%)` }"
                />
                <div
                  :class="['position bar', { animated }]"
                  :style="{
                    animationDuration: duration + 's',
                    animationPlayState: isPlaying
                      ? 'running'
                      : 'paused'
                  }"
                />
              </div>
            </div>
            <div
              v-else
              class="progress-area"
            >
              <div
                ref="progress"
                :class="['ui', 'small', 'vibrant', 'progress']"
              >
                <div class="buffer bar" />
                <div class="position bar" />
              </div>
            </div>
            <div class="progress">
              <template v-if="!isLoadingAudio">
                <a
                  href=""
                  :aria-label="labels.restart"
                  class="left floated timer discrete start"
                  @click.prevent="currentTime = 0"
                >
                  {{ time.parse(Math.round(currentTime)) }}
                </a>
                <span class="right floated timer total">{{ time.parse(Math.round(duration)) }}</span>
              </template>
              <template v-else>
                <span class="left floated timer">{{ $t('components.Queue.meta.startTime') }}</span>
                <span class="right floated timer">{{ $t('components.Queue.meta.startTime') }}</span>
              </template>
            </div>
          </div>
          <player-controls class="desktop-and-below" />
        </template>
      </div>
      <div id="queue">
        <div class="ui basic clearing segment">
          <h2 class="ui header">
            <div class="content">
              <button
                class="ui right floated basic button"
                @click="$store.commit('ui/queueFocused', null)"
              >
                {{ $t('components.Queue.button.close') }}
              </button>
              <button
                class="ui right floated basic button danger"
                @click="clear"
              >
                {{ $t('components.Queue.button.clear') }}
              </button>
              {{ labels.queue }}
              <div class="sub header">
                <div>
                  {{ $t('components.Queue.meta.queuePosition', {index: currentIndex +1, length: queue.length}) }}
                  <span class="middle pipe symbol" />
                  {{ $t('components.Queue.meta.end') }}
                  <span :title="labels.duration">
                    {{ endsIn }}
                  </span>
                </div>
              </div>
            </div>
          </h2>
        </div>
        <virtual-list
          v-if="queueItems.length !== 0"
          ref="list"
          :list="queueItems"
          :component="QueueItem"
          :size="50"
          @reorder="reorderTracks"
          @visible="list.scrollToIndex(currentIndex, 'center')"
        >
          <template #default="{ index, item, classlist }">
            <queue-item
              v-if="index !== undefined"
              :data-index="index"
              :index="index"
              :source="item"
              :class="[...classlist, currentIndex === index && 'active']"
              @play="play"
              @remove="dequeue"
            />
          </template>
          <template #footer>
            <div
              v-if="$store.state.radios.populating"
              class="radio-populating"
            >
              <i class="loading spinner icon" />
              {{ labels.populating }}
            </div>
            <div
              v-if="$store.state.radios.running"
              class="ui info message radio-message"
            >
              <div class="content">
                <h3 class="header">
                  <i class="feed icon" />
                  {{ $t('components.Queue.header.radio') }}
                </h3>
                <p>
                  {{ $t('components.Queue.message.radio') }}
                </p>
                <button
                  class="ui basic primary button"
                  @click="$store.dispatch('radios/stop')"
                >
                  {{ $t('components.Queue.button.stopRadio') }}
                </button>
              </div>
            </div>
          </template>
        </virtual-list>
      </div>
    </div>
  </section>
</template>
