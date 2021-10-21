<template>
  <div
    :class="[
      { active: currentTrack && track.id === currentTrack.id },
      'track-row row mobile',
    ]"
  >
    <div
      v-if="showArt"
      @click.prevent.exact="activateTrack(track, index)"
      class="image left floated column"
    >
      <img
        alt=""
        class="ui artist-track mini image"
        v-if="
          track.album && track.album.cover && track.album.cover.urls.original
        "
        v-lazy="
          $store.getters['instance/absoluteUrl'](
            track.album.cover.urls.medium_square_crop
          )
        "
      />
      <img
        alt=""
        class="ui artist-track mini image"
        v-else-if="
          track.cover
        "
        v-lazy="
          $store.getters['instance/absoluteUrl'](
            track.cover.urls.medium_square_crop
          )
        "
      />
      <img
        alt=""
        class="ui artist-track mini image"
        v-else-if="
          track.artist.cover
        "
        v-lazy="
          $store.getters['instance/absoluteUrl'](
            track.artist.cover.urls.medium_square_crop
          )
        "
      />
      <img
        alt=""
        class="ui artist-track mini image"
        v-else
        src="../../../assets/audio/default-cover.png"
      />
    </div>
    <div
      tabindex=0
      @click="activateTrack(track, index)"
      role="button"
      class="content ellipsis left floated column"
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
      <p class="track-meta mobile">
        {{ track.artist.name }} <span>&#183;</span>
        <human-duration
          v-if="track.uploads[0] && track.uploads[0].duration"
          :duration="track.uploads[0].duration"
        ></human-duration>
      </p>
    </div>
    <div
      v-if="$store.state.auth.authenticated"
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
      ></track-favorite-icon>
    </div>
    <div
      role="button"
      :aria-label="actionsButtonLabel"
      @click.prevent.exact="showTrackModal = !showTrackModal"
      :class="[
        'modal-button',
        'right',
        'floated',
        'column',
        'mobile',
        { 'with-art': showArt },
      ]"
    >
      <i class="ellipsis large vertical icon" />
    </div>
    <track-modal
      @update:show="showTrackModal = $event;"
      :show="showTrackModal"
      :track="track"
      :index="index"
      :is-artist="isArtist"
      :is-album="isAlbum"
    ></track-modal>
  </div>
</template>

<script>
import PlayIndicator from "@/components/audio/track/PlayIndicator";
import { mapActions, mapGetters } from "vuex";
import TrackFavoriteIcon from "@/components/favorites/TrackFavoriteIcon";
import TrackModal from "@/components/audio/track/Modal";
import PlayOptionsMixin from "@/components/mixins/PlayOptions"

export default {
  mixins: [PlayOptionsMixin],
  data() {
    return {
      showTrackModal: false,
    }
  },
  props: {
    tracks: Array,
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
    isArtist: {type: Boolean, required: false, default: false},
    isAlbum: {type: Boolean, required: false, default: false},
  },

  components: {
    PlayIndicator,
    TrackFavoriteIcon,
    TrackModal,
  },
  computed: {
    ...mapGetters({
      currentTrack: "queue/currentTrack",
    }),

    isPlaying() {
      return this.$store.state.player.playing;
    },
    actionsButtonLabel () {
        return this.$pgettext('Content/Track/Icon.Tooltip/Verb', 'Show track actions')
    },
  },

  methods: {
    prettyPosition(position, size) {
      var s = String(position);
      while (s.length < (size || 2)) {
        s = "0" + s;
      }
      return s;
    },

    ...mapActions({
      resumePlayback: "player/resumePlayback",
      pausePlayback: "player/pausePlayback",
    }),
  },
};
</script>
