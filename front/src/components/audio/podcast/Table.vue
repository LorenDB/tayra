<template>
  <div>
    <div class="ui hidden divider"></div>

    <!-- Add a header if needed -->

    <slot name="header"></slot>

    <div>
      <div
        :class="['track-table', 'ui', 'unstackable', 'grid', 'tablet-and-up']"
      >
        <!-- For each item, build a row -->
        <podcast-row
          v-for="(track, index) in tracks"
          :track="track"
          :key="track.id"
          :index="index"
          :tracks="tracks"
          :display-actions="displayActions"
          :show-duration="showDuration"
          :is-podcast="isPodcast"
        ></podcast-row>
      </div>
      <div v-if="paginateResults" class="ui center aligned basic segment desktop-and-up">
        <pagination
          :total="total"
          :current="page"
          :paginate-by="paginateBy"
          v-on="$listeners">
        </pagination>
      </div>
    </div>

    <div
      :class="['track-table', 'ui', 'unstackable', 'grid', 'tablet-and-below']"
    >
      <div v-if="isLoading" class="ui inverted active dimmer">
        <div class="ui loader"></div>
      </div>

      <!-- For each item, build a row -->

      <track-mobile-row
        v-for="(track, index) in tracks"
        :track="track"
        :key="track.id"
        :index="index"
        :tracks="tracks"
        :show-position="showPosition"
        :show-art="showArt"
        :show-duration="showDuration"
        :is-artist="isArtist"
        :is-album="isAlbum"
        :is-podcast="isPodcast"
      ></track-mobile-row>
      <div v-if="paginateResults" class="ui center aligned basic segment tablet-and-below">
        <pagination
          v-if="paginateResults"
          :total="total"
          :current="page"
          :compact="true"
          v-on="$listeners"></pagination>
      </div>
    </div>
  </div>
</template>

<script>
import _ from "@/lodash";
import TrackRow from "@/components/audio/track/Row";
import PodcastRow from "@/components/audio/podcast/Row";
import TrackMobileRow from "@/components/audio/track/MobileRow";
import Pagination from "@/components/Pagination";

export default {
  components: {
    TrackRow,
    TrackMobileRow,
    Pagination,
    PodcastRow,
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
    isArtist: { type: Boolean, required: false, default: false },
    isAlbum: { type: Boolean, required: false, default: false },
    paginateResults: { type: Boolean, required: false, default: true},
    total: { type: Number, required: false},
    page: {type: Number, required: false, default: 1},
    paginateBy: {type: Number, required: false, default: 25},
    isPodcast: {type: Boolean, required: true},
    defaultCover: {type: Object, required: false},
  },

  data() {
    return {
      isLoading: false,
    };
  },

  computed: {
    labels() {
      return {
        title: this.$pgettext("*/*/*/Noun", "Title"),
        album: this.$pgettext("*/*/*/Noun", "Album"),
        artist: this.$pgettext("*/*/*/Noun", "Artist"),
      };
    },
  },
  methods: {
    updatePage: function(page) {
      this.$emit('page-changed', page)
    }
  },
};
</script>
