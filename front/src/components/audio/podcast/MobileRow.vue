<script setup lang="ts">
import type { Track, Artist, Album, Playlist, Library, Channel, Actor } from '~/types'
import type { PlayOptionsProps } from '~/composables/audio/usePlayOptions'
// import type { Track } from '~/types'

import { ref, computed } from 'vue'
import { useGettext } from 'vue3-gettext'
import TrackFavoriteIcon from '~/components/favorites/TrackFavoriteIcon.vue'
import TrackModal from '~/components/audio/track/Modal.vue'
import usePlayOptions from '~/composables/audio/usePlayOptions'
import useQueue from '~/composables/audio/useQueue'
import usePlayer from '~/composables/audio/usePlayer'

interface Props extends PlayOptionsProps {
  track: Track
  index: number

  showArt?: boolean
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

const props = withDefaults(defineProps<Props>(), {
  showArt: true,
  isArtist: false,
  isAlbum: false,

  tracks: () => [],
  artist: null,
  album: null,
  playlist: null,
  library: null,
  channel: null,
  account: null
})

const showTrackModal = ref(false)

const { currentTrack } = useQueue()
const { playing } = usePlayer()
const { activateTrack } = usePlayOptions(props)

const { $pgettext } = useGettext()
const actionsButtonLabel = computed(() => $pgettext('Content/Track/Icon.Tooltip/Verb', 'Show track actions'))
</script>

<template>
  <div
    :class="[
      { active: currentTrack && track.id === currentTrack.id },
      'track-row row mobile',
    ]"
  >
    <div
      v-if="showArt"
      class="image left floated column"
      @click.prevent.exact="activateTrack(track, index)"
    >
      <img
        v-if="track.album?.cover?.urls.original"
        v-lazy="$store.getters['instance/absoluteUrl'](track.album.cover.urls.medium_square_crop)"
        alt=""
        class="ui artist-track mini image"
      >
      <img
        v-else-if="track.cover"
        v-lazy="$store.getters['instance/absoluteUrl'](track.cover.urls.medium_square_crop)"
        alt=""
        class="ui artist-track mini image"
      >
      <img
        v-else-if="track.artist?.cover"
        v-lazy="$store.getters['instance/absoluteUrl'](track.artist.cover.urls.medium_square_crop) "
        alt=""
        class="ui artist-track mini image"
      >
      <img
        v-else
        alt=""
        class="ui artist-track mini image"
        src="../../../assets/audio/default-cover.png"
      >
    </div>
    <div
      tabindex="0"
      role="button"
      class="content ellipsis left floated column"
      @click="activateTrack(track, index)"
    >
      <p
        :class="[
          'track-title',
          'mobile',
          { 'play-indicator': playing && track.id === currentTrack?.id },
        ]"
      >
        {{ track.title }}
      </p>
      <p
        v-if="track.artist?.content_category === 'podcast'"
        class="track-meta mobile"
      >
        <human-date
          class="really discrete"
          :date="track.creation_date"
        />
        <span>&#183;</span>
        <human-duration
          v-if="track.uploads[0] && track.uploads[0].duration"
          :duration="track.uploads[0].duration"
        />
      </p>
      <p
        v-else
        class="track-meta mobile"
      >
        {{ track.artist?.name }} <span>&#183;</span>
        <human-duration
          v-if="track.uploads[0] && track.uploads[0].duration"
          :duration="track.uploads[0].duration"
        />
      </p>
    </div>
    <div
      v-if="$store.state.auth.authenticated && track.artist?.content_category !== 'podcast'"
      :class="[
        'meta',
        'right',
        'floated',
        'column',
        'mobile',
        { 'with-art': showArt },
      ]"
      role="button"
    >
      <track-favorite-icon
        class="tiny"
        :border="false"
        :track="track"
      />
    </div>
    <div
      role="button"
      :aria-label="actionsButtonLabel"
      :class="[
        'modal-button',
        'right',
        'floated',
        'column',
        'mobile',
        { 'with-art': showArt },
      ]"
      @click.prevent.exact="showTrackModal = !showTrackModal"
    >
      <i class="ellipsis large vertical icon" />
    </div>
    <track-modal
      v-model:show="showTrackModal"
      :track="track"
      :index="index"
      :is-artist="isArtist"
      :is-album="isAlbum"
    />
  </div>
</template>
