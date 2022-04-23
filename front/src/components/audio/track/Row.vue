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
            isPlaying &&
            track.id === currentTrack.id &&
            !(track.id == hover)
        "
      />
      <button
        v-else-if="
          currentTrack &&
            !isPlaying &&
            track.id === currentTrack.id &&
            !track.id == hover
        "
        class="ui really tiny basic icon button play-button paused"
      >
        <i class="pause icon" />
      </button>
      <button
        v-else-if="
          currentTrack &&
            isPlaying &&
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
        {{ prettyPosition(track.position) }}
      </span>
    </div>
    <div
      v-if="showArt"
      class="image left floated column"
      role="button"
      @click.prevent.exact="activateTrack(track, index)"
    >
      <img
        v-if="
          track.album && track.album.cover && track.album.cover.urls.original
        "
        v-lazy="
          $store.getters['instance/absoluteUrl'](
            track.album.cover.urls.medium_square_crop
          )
        "
        alt=""
        class="ui artist-track mini image"
      >
      <img
        v-else-if="
          track.cover && track.cover.urls.original
        "
        v-lazy="
          $store.getters['instance/absoluteUrl'](
            track.cover.urls.medium_square_crop
          )
        "
        alt=""
        class="ui artist-track mini image"
      >
      <img
        v-else-if="
          track.artist && track.artist.cover && track.album.cover.urls.original
        "
        v-lazy="
          $store.getters['instance/absoluteUrl'](
            track.cover.urls.medium_square_crop
          )
        "
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
        :to="{ name: 'library.albums.detail', params: { id: track.album.id } }"
      >
        {{ track.album.title }}
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
          params: { id: track.artist.id },
        }"
      >
        {{ track.artist.name }}
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

<script>
import PlayIndicator from '~/components/audio/track/PlayIndicator.vue'
import { mapActions, mapGetters } from 'vuex'
import TrackFavoriteIcon from '~/components/favorites/TrackFavoriteIcon.vue'
import PlayButton from '~/components/audio/PlayButton.vue'
import PlayOptions from '~/components/mixins/PlayOptions.vue'

export default {

  components: {
    PlayIndicator,
    TrackFavoriteIcon,
    PlayButton
  },
  mixins: [PlayOptions],
  props: {
    tracks: { type: Array, required: true },
    showAlbum: { type: Boolean, required: false, default: true },
    showArtist: { type: Boolean, required: false, default: true },
    showPosition: { type: Boolean, required: false, default: false },
    showArt: { type: Boolean, required: false, default: true },
    search: { type: Boolean, required: false, default: false },
    filters: { type: Object, required: false, default: null },
    nextUrl: { type: String, required: false, default: null },
    displayActions: { type: Boolean, required: false, default: true },
    showDuration: { type: Boolean, required: false, default: true },
    index: { type: Number, required: true },
    track: { type: Object, required: true }
  },

  data () {
    return {
      hover: null
    }
  },

  computed: {
    ...mapGetters({
      currentTrack: 'queue/currentTrack'
    }),

    isPlaying () {
      return this.$store.state.player.playing
    }
  },

  methods: {

    prettyPosition (position, size) {
      let s = String(position)
      while (s.length < (size || 2)) {
        s = '0' + s
      }
      return s
    },

    ...mapActions({
      resumePlayback: 'player/resumePlayback',
      pausePlayback: 'player/pausePlayback'
    })
  }
}
</script>
