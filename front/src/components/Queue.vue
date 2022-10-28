<script setup lang="ts">
import type { QueueItemSource } from '~/types'

import { whenever, watchDebounced, useCurrentElement, useScrollLock } from '@vueuse/core'
import { nextTick, ref, computed, watchEffect, onMounted } from 'vue'
import { useFocusTrap } from '@vueuse/integrations/useFocusTrap'
import { useGettext } from 'vue3-gettext'
import { useRouter } from 'vue-router'
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
  endsIn: timeLeft,
  clear
} = useQueue()

const { currentSound } = useTracks()

const queueModal = ref()
const { activate, deactivate } = useFocusTrap(queueModal, { allowOutsideClick: true, preventScroll: true })

const { $pgettext } = useGettext()
const scrollLock = useScrollLock(document.body)
const store = useStore()

const labels = computed(() => ({
  queue: $pgettext('*/*/*', 'Queue'),
  populating: $pgettext('*/*/*', 'Fetching radio track'),
  duration: $pgettext('*/*/*', 'Duration'),
  addArtistContentFilter: $pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Hide content from this artist…'),
  restart: $pgettext('*/*/*', 'Restart track'),
  previous: $pgettext('*/*/*', 'Previous track'),
  next: $pgettext('*/*/*', 'Next track'),
  pause: $pgettext('*/*/*', 'Pause'),
  play: $pgettext('*/*/*', 'Play')
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

const scrollLoop = () => {
  const visible = [...(list.value?.scroller.$_views.values() ?? [])].map(item => item.nr.index)
  if (!visible.includes(currentIndex.value)) {
    list.value?.scrollToIndex(currentIndex.value)
    requestAnimationFrame(scrollLoop)
  }
}

onMounted(scrollLoop)

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

const play = async (index: number) => {
  isPlaying.value = true
  return playTrack(index)
}

const queueItems = computed(() => queue.value.map((track, index) => ({
  ...track,
  id: `${index}-${track.id}`,
  labels: {
    remove: $pgettext('*/*/*', 'Remove'),
    selectTrack: $pgettext('*/*/*', 'Select track'),
    favorite: $pgettext('*/*/*', 'Favorite track')
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
          <div class="cover-container">
            <div class="cover">
              <img
                ref="cover"
                alt=""
                :src="$store.getters['instance/absoluteUrl'](currentTrack.coverUrl)"
              >
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
                  {{ currentTrack.artistName }}
                </router-link>
                <template v-if="currentTrack.albumId !== -1">
                  /
                  <router-link
                    class="discrete link album"
                    :to="{name: 'library.albums.detail', params: {id: currentTrack.albumId }}"
                  >
                    {{ currentTrack.albumTitle }}
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
              <translate translate-context="Sidebar/Player/Error message.Title">
                The track cannot be loaded
              </translate>
            </h3>
            <p v-if="hasNext && isPlaying">
              <translate translate-context="Sidebar/Player/Error message.Paragraph">
                The next track will play automatically in a few seconds…
              </translate>
              <i class="loading spinner icon" />
            </p>
            <p>
              <translate translate-context="Sidebar/Player/Error message.Paragraph">
                You may have a connectivity issue.
              </translate>
            </p>
          </div>
          <div
            v-else-if="currentSound && !currentSound.playable"
            class="ui small warning message"
          >
            <h3 class="header">
              <translate translate-context="Sidebar/Player/No sources">
                The track has no available sources
              </translate>
            </h3>
            <p v-if="hasNext && isPlaying">
              <translate translate-context="Sidebar/Player/Error message.Paragraph">
                The next track will play automatically in a few seconds…
              </translate>
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
                  class="position bar"
                  :style="{ 'transform': `translateX(calc(${progress}% - 100%)` }"
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
                <span class="left floated timer">00:00</span>
                <span class="right floated timer">00:00</span>
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
                <translate translate-context="*/Queue/*/Verb">
                  Close
                </translate>
              </button>
              <button
                class="ui right floated basic button danger"
                @click="clear"
              >
                <translate translate-context="*/Queue/*/Verb">
                  Clear
                </translate>
              </button>
              {{ labels.queue }}
              <div class="sub header">
                <div>
                  <translate
                    translate-context="Sidebar/Queue/Text"
                    :translate-params="{index: currentIndex + 1, length: queue.length}"
                  >
                    Track %{ index } of %{ length }
                  </translate>
                  <template v-if="!$store.state.radios.running">
                    -
                    <span :title="labels.duration">
                      {{ timeLeft }}
                    </span>
                  </template>
                </div>
              </div>
            </div>
          </h2>
        </div>
        <virtual-list
          ref="list"
          :list="queueItems"
          :component="QueueItem"
          :size="50"
          @reorder="reorderTracks"
          @visible="scrollToCurrent('auto')"
          @hidden="scrollLoop"
        >
          <template #default="{ index, item, classList }">
            <queue-item
              :data-index="index"
              :index="index"
              :source="item"
              :class="[...classList, currentIndex === index && 'active']"
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
                  <i class="feed icon" /> <translate translate-context="Sidebar/Player/Title">
                    You have a radio playing
                  </translate>
                </h3>
                <p>
                  <translate translate-context="Sidebar/Player/Paragraph">
                    New tracks will be appended here automatically.
                  </translate>
                </p>
                <button
                  class="ui basic primary button"
                  @click="$store.dispatch('radios/stop')"
                >
                  <translate translate-context="*/Player/Button.Label/Short, Verb">
                    Stop radio
                  </translate>
                </button>
              </div>
            </div>
          </template>
        </virtual-list>
      </div>
    </div>
  </section>
</template>
