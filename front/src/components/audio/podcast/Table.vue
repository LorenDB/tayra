<template>
  <div>
    <div class="ui hidden divider" />

    <!-- Add a header if needed -->

    <slot name="header" />

    <div>
      <div
        :class="['track-table', 'ui', 'unstackable', 'grid', 'tablet-and-up']"
      >
        <!-- For each item, build a row -->
        <podcast-row
          v-for="(track, index) in tracks"
          :key="track.id"
          :track="track"
          :index="index"
          :tracks="tracks"
          :display-actions="displayActions"
          :show-duration="showDuration"
          :is-podcast="isPodcast"
        />
      </div>
      <div
        v-if="paginateResults"
        class="ui center aligned basic segment desktop-and-up"
      >
        <pagination
          :total="total"
          :current="page"
          :paginate-by="paginateBy"
          v-bind="$attrs"
        />
      </div>
    </div>

    <div
      :class="['track-table', 'ui', 'unstackable', 'grid', 'tablet-and-below']"
    >
      <div
        v-if="isLoading"
        class="ui inverted active dimmer"
      >
        <div class="ui loader" />
      </div>

      <!-- For each item, build a row -->

      <track-mobile-row
        v-for="(track, index) in tracks"
        :key="track.id"
        :track="track"
        :index="index"
        :tracks="tracks"
        :show-position="showPosition"
        :show-art="showArt"
        :show-duration="showDuration"
        :is-artist="isArtist"
        :is-album="isAlbum"
        :is-podcast="isPodcast"
      />
      <div
        v-if="paginateResults"
        class="ui center aligned basic segment tablet-and-below"
      >
        <pagination
          v-if="paginateResults"
          :total="total"
          :current="page"
          :compact="true"
          v-bind="$attrs"
        />
      </div>
    </div>
  </div>
</template>

<script>
import PodcastRow from '~/components/audio/podcast/Row.vue'
import TrackMobileRow from '~/components/audio/track/MobileRow.vue'
import Pagination from '~/components/Pagination.vue'

export default {
  components: {
    TrackMobileRow,
    Pagination,
    PodcastRow
  },

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
    isArtist: { type: Boolean, required: false, default: false },
    isAlbum: { type: Boolean, required: false, default: false },
    paginateResults: { type: Boolean, required: false, default: true },
    total: { type: Number, required: false, default: 0 },
    page: { type: Number, required: false, default: 1 },
    paginateBy: { type: Number, required: false, default: 25 },
    isPodcast: { type: Boolean, required: true },
    defaultCover: { type: Object, required: false, default: () => { return {} } }
  },

  data () {
    return {
      isLoading: false
    }
  },

  computed: {
    labels () {
      return {
        title: this.$pgettext('*/*/*/Noun', 'Title'),
        album: this.$pgettext('*/*/*/Noun', 'Album'),
        artist: this.$pgettext('*/*/*/Noun', 'Artist')
      }
    }
  }
}
</script>
