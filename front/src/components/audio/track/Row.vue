<script setup lang="ts">
import { Track, Artist, Album, Playlist, Library, Channel, Actor } from '~/types'
// import { Track } from '~/types'
import PlayIndicator from '~/components/audio/track/PlayIndicator.vue'
import TrackFavoriteIcon from '~/components/favorites/TrackFavoriteIcon.vue'
import PlayButton from '~/components/audio/PlayButton.vue'
import usePlayOptions, { PlayOptionsProps } from '~/composables/audio/usePlayOptions'
import useQueue from '~/composables/audio/useQueue'
import usePlayer from '~/composables/audio/usePlayer'
import { ref } from 'vue'

interface Props extends PlayOptionsProps {
  tracks: Track[]
  track: Track
  index: number

  showAlbum?: boolean
  showArt?: boolean
  showArtist?: boolean
  showDuration?: boolean
  showPosition?: boolean
  displayActions?: boolean

  // TODO(wvffle): Remove after https://github.com/vuejs/core/pull/4512 is merged
  isPlayable?: boolean
  artist?: Artist | null
  album?: Album | null
  playlist?: Playlist | null
  library?: Library | null
  channel?: Channel | null
  account?: Actor | null
}

const props = withDefaults(defineProps<Props>(), {
  showAlbum: true,
  showArt: true,
  showArtist: true,
  showDuration: true,
  showPosition: false,
  displayActions: true
})

const hover = ref<string | null>(null)

const { playing } = usePlayer()
const { currentTrack } = useQueue()
const { activateTrack } = usePlayOptions(props)

</script>

<template>
  <div
    :class="[
      { active: currentTrack && track.id === currentTrack.id },
      'track-row row',
    ]"
    @mouseover="hover = track.id"
    @mouseleave="hover = null"
    @dblclick="activateTrack(track, index)"
  >
    <div
      class="actions one wide left floated column"
      role="button"
      @click.prevent.exact="activateTrack(track, index)"
    >
      <play-indicator
        v-if="
          !$store.state.player.isLoadingAudio &&
            currentTrack &&
            playing &&
            track.id === currentTrack.id &&
            !(track.id == hover)
        "
      />
      <button
        v-else-if="
          currentTrack &&
            !playing &&
            track.id === currentTrack.id &&
            track.id !== hover
        "
        class="ui really tiny basic icon button play-button paused"
      >
        <i class="pause icon" />
      </button>
      <button
        v-else-if="
          currentTrack &&
            playing &&
            track.id === currentTrack.id &&
            track.id == hover
        "
        class="ui really tiny basic icon button play-button"
      >
        <i class="pause icon" />
      </button>
      <button
        v-else-if="track.id == hover"
        class="ui really tiny basic icon button play-button"
      >
        <i class="play icon" />
      </button>
      <span
        v-else-if="showPosition"
        class="track-position"
      >
        {{ (track.position as unknown as string).padStart(2, '0') }}
      </span>
    </div>
    <div
      v-if="showArt"
      class="image left floated column"
      role="button"
      @click.prevent.exact="activateTrack(track, index)"
    >
      <img
        v-if="track.album?.cover?.urls.original"
        v-lazy="$store.getters['instance/absoluteUrl'](track.album.cover.urls.medium_square_crop)"
        alt=""
        class="ui artist-track mini image"
      >
      <img
        v-else-if="track.cover?.urls.original"
        v-lazy="$store.getters['instance/absoluteUrl'](track.cover.urls.medium_square_crop)"
        alt=""
        class="ui artist-track mini image"
      >
      <img
        v-else-if="track.artist?.cover?.urls.original"
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
      class="content ellipsis left floated column"
    >
      <a
        @click="activateTrack(track, index)"
      >
        {{ track.title }}
      </a>
    </div>
    <div
      v-if="showAlbum"
      class="content ellipsis left floated column"
    >
      <router-link
        :to="{ name: 'library.albums.detail', params: { id: track.album?.id } }"
      >
        {{ track.album?.title }}
      </router-link>
    </div>
    <div
      v-if="showArtist"
      class="content ellipsis left floated column"
    >
      <router-link
        class="artist link"
        :to="{
          name: 'library.artists.detail',
          params: { id: track.artist?.id },
        }"
      >
        {{ track.artist?.name }}
      </router-link>
    </div>
    <div
      v-if="$store.state.auth.authenticated"
      class="meta right floated column"
    >
      <track-favorite-icon
        class="tiny"
        :border="false"
        :track="track"
      />
    </div>
    <div
      v-if="showDuration"
      class="meta right floated column"
    >
      <human-duration
        v-if="track.uploads[0] && track.uploads[0].duration"
        :duration="track.uploads[0].duration"
      />
    </div>
    <div
      v-if="displayActions"
      class="meta right floated column"
    >
      <play-button
        id="playmenu"
        class="play-button basic icon"
        :dropdown-only="true"
        :is-playable="track.is_playable"
        :dropdown-icon-classes="[
          'ellipsis',
          'vertical',
          'large really discrete',
        ]"
        :track="track"
      />
    </div>
  </div>
</template>
