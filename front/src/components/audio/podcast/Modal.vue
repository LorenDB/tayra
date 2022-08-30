<script setup lang="ts">
import type { Track, Artist, Album, Playlist, Library, Channel, Actor } from '~/types'
import type { PlayOptionsProps } from '~/composables/audio/usePlayOptions'
// import type { Track } from '~/types'

import { useStore } from '~/store'
import { useGettext } from 'vue3-gettext'
import SemanticModal from '~/components/semantic/Modal.vue'
import { computed, ref } from 'vue'
import usePlayOptions from '~/composables/audio/usePlayOptions'
import useReport from '~/composables/moderation/useReport'
import { useVModel } from '@vueuse/core'

interface Events {
  (e: 'update:show', value: boolean): void
}

interface Props extends PlayOptionsProps {
  track: Track
  index: number
  show: boolean

  isArtist?: boolean
  isAlbum?: boolean

  // TODO(wvffle): Remove after https://github.com/vuejs/core/pull/4512 is merged
  isPlayable?: boolean
  tracks?: Track[]
  artist?: Artist | null
  album?: Album | null
  playlist?: Playlist | null
  library?: Library | null
  channel?: Channel | null
  account?: Actor | null
}

const emit = defineEmits<Events>()
const props = withDefaults(defineProps<Props>(), {
  isArtist: false,
  isAlbum: false
})

const modal = ref()

const show = useVModel(props, 'show', emit)

const { report, getReportableObjects } = useReport()
const { enqueue, enqueueNext } = usePlayOptions(props)
const store = useStore()

const isFavorite = computed(() => store.getters['favorites/isFavorite'](props.track.id))

const { $pgettext } = useGettext()
const favoriteButton = computed(() => isFavorite.value
  ? $pgettext('Content/Track/Icon.Tooltip/Verb', 'Remove from favorites')
  : $pgettext('Content/Track/*/Verb', 'Add to favorites')
)

const trackDetailsButton = computed(() => props.track.artist?.content_category === 'podcast'
  ? $pgettext('*/Queue/Dropdown/Button/Label/Short', 'Episode details')
  : $pgettext('*/Queue/Dropdown/Button/Label/Short', 'Track details')
)

const albumDetailsButton = computed(() => props.track.artist?.content_category === 'podcast'
  ? $pgettext('*/Queue/Dropdown/Button/Label/Short', 'View series')
  : $pgettext('*/Queue/Dropdown/Button/Label/Short', 'View album')
)

const artistDetailsButton = computed(() => props.track.artist?.content_category === 'podcast'
  ? $pgettext('*/Queue/Dropdown/Button/Label/Short', 'View channel')
  : $pgettext('*/Queue/Dropdown/Button/Label/Short', 'View artist')
)

const labels = computed(() => ({
  startRadio: $pgettext('*/Queue/Dropdown/Button/Title', 'Play radio'),
  playNow: $pgettext('*/Queue/Dropdown/Button/Title', 'Play now'),
  addToQueue: $pgettext('*/Queue/Dropdown/Button/Title', 'Add to queue'),
  playNext: $pgettext('*/Queue/Dropdown/Button/Title', 'Play next'),
  addToPlaylist: $pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Add to playlist…')
}))
</script>

<template>
  <semantic-modal
    ref="modal"
    v-model:show="show"
    :scrolling="true"
    :additional-classes="['scrolling-track-options']"
  >
    <div class="header">
      <div class="ui large centered rounded image">
        <img
          v-if="track.album && track.album.cover && track.album.cover.urls.original"
          v-lazy="
            $store.getters['instance/absoluteUrl'](
              track.album.cover.urls.medium_square_crop
            )
          "
          alt=""
          class="ui centered image"
        >
        <img
          v-else-if="track.cover"
          v-lazy="
            $store.getters['instance/absoluteUrl'](
              track.cover.urls.medium_square_crop
            )
          "
          alt=""
          class="ui centered image"
        >
        <img
          v-else-if="track.artist?.cover"
          v-lazy="
            $store.getters['instance/absoluteUrl'](
              track.artist.cover.urls.medium_square_crop
            )
          "
          alt=""
          class="ui centered image"
        >
        <img
          v-else
          alt=""
          class="ui centered image"
          src="../../../assets/audio/default-cover.png"
        >
      </div>
      <h3 class="track-modal-title">
        {{ track.title }}
      </h3>
      <h4 class="track-modal-subtitle">
        {{ track.artist?.name }}
      </h4>
    </div>
    <div class="ui hidden divider" />
    <div class="content">
      <div class="ui one column unstackable grid">
        <div
          v-if="$store.state.auth.authenticated && track.artist?.content_category !== 'podcast'"
          class="row"
        >
          <div
            tabindex="0"
            class="column"
            role="button"
            :aria-label="favoriteButton"
            @click.stop="$store.dispatch('favorites/toggle', track.id)"
          >
            <i
              :class="[
                'heart',
                'favorite-icon',
                { favorited: isFavorite },
                { pink: isFavorite },
                'icon',
                'track-modal',
                'list-icon',
              ]"
            />
            <span class="track-modal list-item">{{ favoriteButton }}</span>
          </div>
        </div>
        <div class="row">
          <div
            class="column"
            role="button"
            :aria-label="labels.addToQueue"
            @click.stop.prevent="
              enqueue();
              modal.closeModal();
            "
          >
            <i class="plus icon track-modal list-icon" />
            <span class="track-modal list-item">{{ labels.addToQueue }}</span>
          </div>
        </div>
        <div class="row">
          <div
            class="column"
            role="button"
            :aria-label="labels.playNext"
            @click.stop.prevent="
              enqueueNext(true);
              modal.closeModal();
            "
          >
            <i class="step forward icon track-modal list-icon" />
            <span class="track-modal list-item">{{ labels.playNext }}</span>
          </div>
        </div>
        <div class="row">
          <div
            class="column"
            role="button"
            :aria-label="labels.startRadio"
            @click.stop.prevent="
              $store.dispatch('radios/start', {
                type: 'similar',
                objectId: track.id,
              });
              modal.closeModal();
            "
          >
            <i class="rss icon track-modal list-icon" />
            <span class="track-modal list-item">{{ labels.startRadio }}</span>
          </div>
        </div>
        <div class="row">
          <div
            class="column"
            role="button"
            :aria-label="labels.addToPlaylist"
            @click.stop="$store.commit('playlists/chooseTrack', track)"
          >
            <i class="list icon track-modal list-icon" />
            <span class="track-modal list-item">{{
              labels.addToPlaylist
            }}</span>
          </div>
        </div>
        <div class="ui divider" />
        <div
          v-if="!isAlbum && track.album"
          class="row"
        >
          <div
            class="column"
            role="button"
            :aria-label="albumDetailsButton"
            @click.prevent.exact="
              $router.push({
                name: 'library.albums.detail',
                params: { id: track.album?.id },
              })
            "
          >
            <i class="compact disc icon track-modal list-icon" />
            <span class="track-modal list-item">{{
              albumDetailsButton
            }}</span>
          </div>
        </div>
        <div
          v-if="!isArtist"
          class="row"
        >
          <div
            class="column"
            role="button"
            :aria-label="artistDetailsButton"
            @click.prevent.exact="
              $router.push({
                name: 'library.artists.detail',
                params: { id: track.artist?.id },
              })
            "
          >
            <i class="user icon track-modal list-icon" />
            <span class="track-modal list-item">{{
              artistDetailsButton
            }}</span>
          </div>
        </div>
        <div class="row">
          <div
            class="column"
            role="button"
            :aria-label="trackDetailsButton"
            @click.prevent.exact="
              $router.push({
                name: 'library.tracks.detail',
                params: { id: track.id },
              })
            "
          >
            <i class="info icon track-modal list-icon" />
            <span class="track-modal list-item">{{
              trackDetailsButton
            }}</span>
          </div>
        </div>
        <div class="ui divider" />
        <div
          v-for="obj in getReportableObjects({ track, album: track.album, artist: track.artist })"
          :key="obj.target.type + obj.target.id"
          class="row"
          @click.stop.prevent="report(obj)"
        >
          <div class="column">
            <i class="share icon track-modal list-icon" /><span
              class="track-modal list-item"
            >{{ obj.label }}</span>
          </div>
        </div>
      </div>
    </div>
  </semantic-modal>
</template>
