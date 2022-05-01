<template>
  <div>
    <!-- Show the search bar if search is true -->
    <inline-search-bar
      v-if="search"
      v-model="query"
      @search="
        currentPage = 1;
        additionalTracks = [];
        fetchData('tracks/');
      "
    />

    <!-- Add a header if needed -->

    <slot name="header" />

    <!-- Show a message if no tracks are available -->

    <slot
      v-if="!isLoading && allTracks.length === 0"
      name="empty-state"
    >
      <empty-state
        :refresh="true"
        @refresh="fetchData('tracks/')"
      />
    </slot>
    <div v-else>
      <div
        :class="['track-table', 'ui', 'unstackable', 'grid', 'tablet-and-up']"
      >
        <div
          v-if="isLoading"
          class="ui inverted active dimmer"
        >
          <div class="ui loader" />
        </div>
        <div class="track-table row">
          <div
            v-if="showPosition"
            class="actions left floated column"
          >
            <i class="hashtag icon" />
          </div>
          <div
            v-else
            class="actions left floated column"
          />
          <div
            v-if="showArt"
            class="image left floated column"
          />
          <div class="content ellipsis left floated column">
            <b>{{ labels.title }}</b>
          </div>
          <div
            v-if="showAlbum"
            class="content ellipsisleft floated column"
          >
            <b>{{ labels.album }}</b>
          </div>
          <div
            v-if="showArtist"
            class="content ellipsis left floated column"
          >
            <b>{{ labels.artist }}</b>
          </div>
          <div
            v-if="$store.state.auth.authenticated"
            class="meta right floated column"
          />
          <div
            v-if="showDuration"
            class="meta right floated column"
          >
            <i
              class="clock outline icon"
              style="padding: 0.5rem"
            />
          </div>
          <div
            v-if="displayActions"
            class="meta right floated column"
          />
        </div>

        <!-- For each item, build a row -->

        <track-row
          v-for="(track, index) in allTracks"
          :key="track.id"
          :track="track"
          :index="index"
          :tracks="allTracks"
          :show-album="showAlbum"
          :show-artist="showArtist"
          :show-position="showPosition"
          :show-art="showArt"
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
          :total="totalTracks"
          :current=" tracks.length > 0 ? page : currentPage"
          :paginate-by="paginateBy"
          @page-changed="updatePage"
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
        v-for="(track, index) in allTracks"
        :key="track.id"
        :track="track"
        :index="index"
        :tracks="allTracks"
        :show-position="showPosition"
        :show-art="showArt"
        :show-duration="showDuration"
        :is-artist="isArtist"
        :is-album="isAlbum"
        :is-podcast="isPodcast"
      />
      <div
        v-if="paginateResults && totalTracks > paginateBy"
        class="ui center aligned basic segment tablet-and-below"
      >
        <pagination
          v-if="paginateResults && totalTracks > paginateBy"
          :paginate-by="paginateBy"
          :total="totalTracks"
          :current="tracks.length > 0 ? page : {currentPage}"
          :compact="true"
          @page-changed="updatePage"
        />
      </div>
    </div>
  </div>
</template>

<script>
import { clone, uniqBy } from 'lodash-es'
import axios from 'axios'
import TrackRow from '~/components/audio/track/Row.vue'
import TrackMobileRow from '~/components/audio/track/MobileRow.vue'
import Pagination from '~/components/Pagination.vue'

export default {
  components: {
    TrackRow,
    TrackMobileRow,
    Pagination
  },

  props: {
    tracks: { type: Array, default: () => { return [] } },
    showAlbum: { type: Boolean, required: false, default: true },
    showArtist: { type: Boolean, required: false, default: true },
    showPosition: { type: Boolean, required: false, default: false },
    showArt: { type: Boolean, required: false, default: true },
    search: { type: Boolean, required: false, default: false },
    filters: { type: Object, required: false, default: () => { return {} } },
    nextUrl: { type: String, required: false, default: null },
    displayActions: { type: Boolean, required: false, default: true },
    showDuration: { type: Boolean, required: false, default: true },
    isArtist: { type: Boolean, required: false, default: false },
    isAlbum: { type: Boolean, required: false, default: false },
    isPodcast: { type: Boolean, required: false, default: false },
    paginateResults: { type: Boolean, required: false, default: true },
    total: { type: Number, required: false, default: 0 },
    page: { type: Number, required: false, default: 1 },
    paginateBy: { type: Number, required: false, default: 25 }
  },

  data () {
    return {
      fetchDataUrl: this.nextUrl,
      isLoading: false,
      additionalTracks: [],
      query: '',
      totalTracks: this.total,
      currentPage: this.page
    }
  },
  computed: {
    allTracks () {
      const tracks = (this.tracks || []).concat(this.additionalTracks)
      return uniqBy(tracks, 'id')
    },

    labels () {
      return {
        title: this.$pgettext('*/*/*/Noun', 'Title'),
        album: this.$pgettext('*/*/*/Noun', 'Album'),
        artist: this.$pgettext('*/*/*/Noun', 'Artist')
      }
    }
  },
  created () {
    if (this.tracks.length === 0) {
      this.fetchData('tracks/')
    }
  },
  methods: {
    async fetchData (url) {
      if (!url) {
        return
      }
      this.isLoading = true
      const self = this
      const params = clone(this.filters)
      params.page_size = this.paginateBy
      params.page = this.currentPage
      params.include_channels = true
      params.q = this.query
      const tracksPromise = await axios.get(url, { params: params })
      try {
        self.fetchDataUrl = tracksPromise.data.next
        self.additionalTracks = tracksPromise.data.results
        self.totalTracks = tracksPromise.data.count
        self.$emit('fetched', tracksPromise.data)
        self.isLoading = false
      } catch (e) {
        self.isLoading = false
        self.errors = e.backendErrors
      }
    },
    updatePage: function (page) {
      if (this.tracks.length === 0) {
        this.currentPage = page
        this.fetchData('tracks/')
      } else {
        this.$emit('page-changed', page)
      }
    }
  }
}
</script>
