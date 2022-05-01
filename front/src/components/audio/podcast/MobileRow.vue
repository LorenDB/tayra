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
          track.cover
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
          track.artist.cover
        "
        v-lazy="
          $store.getters['instance/absoluteUrl'](
            track.artist.cover.urls.medium_square_crop
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
      role="button"
      class="content ellipsis left floated column"
      @click="activateTrack(track, index)"
    >
      <p
        :class="[
          'track-title',
          'mobile',
          { 'play-indicator': isPlaying && currentTrack && track.id === currentTrack.id },
        ]"
      >
        {{ track.title }}
      </p>
      <p
        v-if="track.artist.content_category === 'podcast'"
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
        {{ track.artist.name }} <span>&#183;</span>
        <human-duration
          v-if="track.uploads[0] && track.uploads[0].duration"
          :duration="track.uploads[0].duration"
        />
      </p>
    </div>
    <div
      v-if="$store.state.auth.authenticated && track.artist.content_category !== 'podcast'"
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

<script>
import { mapActions, mapGetters } from 'vuex'
import TrackFavoriteIcon from '~/components/favorites/TrackFavoriteIcon.vue'
import TrackModal from '~/components/audio/track/Modal.vue'
import PlayOptionsMixin from '~/components/mixins/PlayOptions.vue'

export default {

  components: {
    TrackFavoriteIcon,
    TrackModal
  },
  mixins: [PlayOptionsMixin],
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
    track: { type: Object, required: true },
    isArtist: { type: Boolean, required: false, default: false },
    isAlbum: { type: Boolean, required: false, default: false }
  },
  data () {
    return {
      showTrackModal: false
    }
  },
  computed: {
    ...mapGetters({
      currentTrack: 'queue/currentTrack'
    }),

    isPlaying () {
      return this.$store.state.player.playing
    },
    actionsButtonLabel () {
      return this.$pgettext('Content/Track/Icon.Tooltip/Verb', 'Show track actions')
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
