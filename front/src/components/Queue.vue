<script setup lang="ts">
import { useStore } from '~/store'
import { nextTick, ref, computed, onBeforeMount, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import time from '~/utils/time'
import { useFocusTrap } from '@vueuse/integrations/useFocusTrap'
import TrackFavoriteIcon from '~/components/favorites/TrackFavoriteIcon.vue'
import TrackPlaylistIcon from '~/components/playlists/TrackPlaylistIcon.vue'
import Draggable from 'vuedraggable'
import { whenever, watchDebounced } from '@vueuse/core'
import { useGettext } from 'vue3-gettext'
import useQueue from '~/composables/audio/useQueue'
import usePlayer from '~/composables/audio/usePlayer'

const queueModal = ref()

let savedScroll = 0
onBeforeMount(() => (savedScroll = window.scrollY))
onUnmounted(() => {
  document.body.parentElement?.setAttribute('style', 'scroll-behavior: auto')
  window.scrollTo({ top: savedScroll, behavior: undefined })
  document.body.parentElement?.removeAttribute('style')
})

const { activate } = useFocusTrap(queueModal, { allowOutsideClick: true })
activate()

const store = useStore()
const currentIndex = computed(() => store.state.queue.currentIndex)

const scrollToCurrent = async () => {
  await nextTick()
  const item = queueModal.value?.querySelector('.queue-item.active')
  item?.scrollIntoView({ behavior: store.state.ui.queueFocused ? 'smooth' : 'auto' })
}

const { $pgettext } = useGettext()

const {
  playing,
  loading: isLoadingAudio,
  errored,
  duration,
  durationFormatted,
  currentTimeFormatted,
  progress,
  bufferProgress,
  currentTime,
  pause,
  resume
} = usePlayer()

const {
  currentTrack,
  hasNext,
  isEmpty: emptyQueue,
  tracks,
  reorder: reorderTracks,
  endsIn: timeLeft,
  removeTrack,
  clear,
  next,
  previous
} = useQueue()

const reorder = (event: { oldIndex: number, newIndex: number }) => reorderTracks(event.oldIndex, event.newIndex)

const labels = computed(() => ({
  queue: $pgettext('*/*/*', 'Queue'),
  duration: $pgettext('*/*/*', 'Duration'),
  addArtistContentFilter: $pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Hide content from this artist…'),
  restart: $pgettext('*/*/*', 'Restart track'),
  previous: $pgettext('*/*/*', 'Previous track'),
  next: $pgettext('*/*/*', 'Next track'),
  pause: $pgettext('*/*/*', 'Pause'),
  play: $pgettext('*/*/*', 'Play'),
  remove: $pgettext('*/*/*', 'Remove'),
  selectTrack: $pgettext('*/*/*', 'Select track')
}))

watchDebounced(() => store.state.ui.queueFocused, scrollToCurrent, { debounce: 400 })
whenever(currentTrack, scrollToCurrent, { immediate: true })

whenever(
  () => tracks.value.length === 0,
  () => store.commit('ui/queueFocused', null),
  { immediate: true }
)

const router = useRouter()
router.beforeEach(() => store.commit('ui/queueFocused', null))

const progressBar = ref()
const touchProgress = (event: MouseEvent) => {
  const time = ((event.clientX - (event.target as Element).getBoundingClientRect().left) / progressBar.value.offsetWidth) * duration.value
  currentTime.value = time
}

const play = (index: number) => {
  store.dispatch('queue/currentIndex', index)
  resume()
}
</script>

<template>
  <section
    ref="queueModal"
    class="main with-background component-queue"
    :aria-label="labels.queue"
  >
    <div id="queue-grid">
      <div
        id="player"
        class="ui basic segment"
      >
        <template v-if="currentTrack">
          <div class="cover-container">
            <div class="cover">
              <img
                v-if="currentTrack.cover && currentTrack.cover.urls.large_square_crop"
                ref="cover"
                alt=""
                :src="$store.getters['instance/absoluteUrl'](currentTrack.cover.urls.large_square_crop)"
              >
              <img
                v-else-if="currentTrack.album && currentTrack.album.cover && currentTrack.album.cover.urls.large_square_crop"
                ref="cover"
                alt=""
                :src="$store.getters['instance/absoluteUrl'](currentTrack.album.cover.urls.large_square_crop)"
              >
              <img
                v-else
                class="ui image"
                alt=""
                src="../assets/audio/default-cover.png"
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
                  :to="{name: 'library.artists.detail', params: {id: currentTrack.artist.id }}"
                >
                  {{ currentTrack.artist.name }}
                </router-link>
                <template v-if="currentTrack.album">
                  /
                  <router-link
                    class="discrete link album"
                    :to="{name: 'library.albums.detail', params: {id: currentTrack.album.id }}"
                  >
                    {{ currentTrack.album.title }}
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
            <p v-if="hasNext && playing && $store.state.player.errorCount < $store.state.player.maxConsecutiveErrors">
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
              @click="$store.dispatch('moderation/hide', {type: 'artist', target: currentTrack.artist})"
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
                  :style="{ 'transform': `translateX(${progress - 100}%)` }"
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
                >{{ currentTimeFormatted }}</a>
                <span class="right floated timer total">{{ durationFormatted }}</span>
              </template>
              <template v-else>
                <span class="left floated timer">00:00</span>
                <span class="right floated timer">00:00</span>
              </template>
            </div>
          </div>
          <div class="player-controls desktop-and-below">
            <span
              role="button"
              :title="labels.previous"
              :aria-label="labels.previous"
              class="control"
              :disabled="emptyQueue || null"
              @click.prevent.stop="previous"
            >
              <i :class="['ui', 'backward step', {'disabled': emptyQueue}, 'icon']" />
            </span>

            <span
              v-if="!playing"
              role="button"
              :title="labels.play"
              :aria-label="labels.play"
              class="control"
              @click.prevent.stop="resume"
            >
              <i :class="['ui', 'play', {'disabled': !currentTrack}, 'icon']" />
            </span>
            <span
              v-else
              role="button"
              :title="labels.pause"
              :aria-label="labels.pause"
              class="control"
              @click.prevent.stop="pause"
            >
              <i :class="['ui', 'pause', {'disabled': !currentTrack}, 'icon']" />
            </span>
            <span
              role="button"
              :title="labels.next"
              :aria-label="labels.next"
              class="control"
              :disabled="hasNext || null"
              @click.prevent.stop="next"
            >
              <i :class="['ui', {'disabled': !hasNext}, 'forward step', 'icon']" />
            </span>
          </div>
        </template>
      </div>
      <div>
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
                    :translate-params="{index: currentIndex + 1, length: tracks.length}"
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
        <div>
          <table class="ui compact very basic fixed single line selectable unstackable table">
            <draggable
              v-model="tracks"
              handle=".handle"
              item-key="id"
              tag="tbody"
              @update="reorder"
            >
              <template #item="{ element: track, index }">
                <tr
                  :key="track.id"
                  :class="['queue-item', {'active': index === currentIndex}]"
                >
                  <td class="handle">
                    <i class="grip lines icon" />
                  </td>
                  <td
                    class="image-cell"
                    @click="play(index)"
                  >
                    <img
                      v-if="track.cover && track.cover.urls.original"
                      class="ui mini image"
                      alt=""
                      :src="$store.getters['instance/absoluteUrl'](track.cover.urls.medium_square_crop)"
                    >
                    <img
                      v-else-if="track.album && track.album.cover && track.album.cover.urls.original"
                      class="ui mini image"
                      alt=""
                      :src="$store.getters['instance/absoluteUrl'](track.album.cover.urls.medium_square_crop)"
                    >
                    <img
                      v-else
                      class="ui mini image"
                      alt=""
                      src="../assets/audio/default-cover.png"
                    >
                  </td>
                  <td
                    colspan="3"
                    @click="play(index)"
                  >
                    <button
                      class="title reset ellipsis"
                      :title="track.title"
                      :aria-label="labels.selectTrack"
                    >
                      <strong>{{ track.title }}</strong><br>
                      <span>
                        {{ track.artist.name }}
                      </span>
                    </button>
                  </td>
                  <td class="duration-cell">
                    <template v-if="track.uploads.length > 0">
                      {{ time.durationFormatted(track.uploads[0].duration) }}
                    </template>
                  </td>
                  <td class="controls">
                    <template v-if="$store.getters['favorites/isFavorite'](track.id)">
                      <i class="pink heart icon" />
                    </template>
                    <button
                      :aria-label="labels.remove"
                      :title="labels.remove"
                      :class="['ui', 'really', 'tiny', 'basic', 'circular', 'icon', 'button']"
                      @click.stop="removeTrack(index)"
                    >
                      <i class="x icon" />
                    </button>
                  </td>
                </tr>
              </template>
            </draggable>
          </table>
          <div
            v-if="$store.state.radios.running"
            class="ui info message"
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
        </div>
      </div>
    </div>
  </section>
</template>
