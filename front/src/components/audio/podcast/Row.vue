<template>
  <div
    :class="[
      { active: currentTrack && track.id === currentTrack.id },
      'track-row podcast row',
    ]"
    @mouseover="hover = track.id"
    @mouseleave="hover = null"
    @dblclick="activateTrack(track, index)"
  >
    <div
      v-if="showArt"
      class="image left floated column"
      role="button"
      @click.prevent.exact="activateTrack(track, index)"
    >
      <img
        alt=""
        class="ui artist-track mini image"
        v-if="
          track.cover && track.cover.urls.original
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
          defaultCover
        "
        v-lazy="
          $store.getters['instance/absoluteUrl'](
            defaultCover.cover.urls.medium_square_crop
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
    <div tabindex=0 class="content left floated column">
      <a
        class="podcast-episode-title ellipsis"
        @click.prevent.exact="activateTrack(track, index)">{{ track.title }}</a>
      <p class="podcast-episode-meta">{{ description.text }}</p>
    </div>
    <div v-if="displayActions" class="meta right floated column">
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
      ></play-button>
    </div>
  </div>
</template>

<script>
import axios from 'axios'
import PlayIndicator from "@/components/audio/track/PlayIndicator";
import { mapActions, mapGetters } from "vuex";
import PlayButton from "@/components/audio/PlayButton";
import PlayOptions from "@/components/mixins/PlayOptions";

export default {
  mixins: [PlayOptions],
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
    defaultCover: { type: Object, required: false },
  },

  data() {
    return {
      hover: null,
      errors: null,
      description: null,
    }
  },

  created () {
    this.fetchData('tracks/' + this.track.id + '/' )
	},

  components: {
    PlayIndicator,
    PlayButton,
  },

  computed: {
    ...mapGetters({
      currentTrack: "queue/currentTrack",
    }),

    isPlaying() {
      return this.$store.state.player.playing;
    },
  },

  methods: {
    async fetchData (url) {
      if (!url) {
        return
      }
      this.isLoading = true
      let self = this
      try {
        let channelsPromise = await axios.get(url)
        self.description = channelsPromise.data.description
        self.isLoading = false
      } catch(e) {
        self.isLoading = false
        self.errors = error.backendErrors
      }
    },

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
