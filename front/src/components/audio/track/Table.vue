<template>
  <div>
    <!-- Show the search bar if search is true -->
    <inline-search-bar
      v-if="search"
      v-model="query"
      @search="
        additionalTracks = [];
        fetchData();
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
          :total="total"
          :current="page"
          :paginate-by="paginateBy"
          v-on="$listeners"
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
        v-if="paginateResults"
        class="ui center aligned basic segment tablet-and-below"
      >
        <pagination
          v-if="paginateResults"
          :total="total"
          :current="page"
          :compact="true"
          v-on="$listeners"
        />
      </div>
    </div>
  </div>
</template>

<script>
import _ from '@/lodash'
import axios from 'axios'
import TrackRow from '@/components/audio/track/Row'
import TrackMobileRow from '@/components/audio/track/MobileRow'
import Pagination from '@/components/Pagination'

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
    filters: { type: Object, required: false, default: null },
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
      query: ''
    }
  },

  computed: {
    allTracks () {
      return (this.tracks || []).concat(this.additionalTracks)
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
    if (!this.tracks) {
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
      const params = _.clone(this.filters)
      const tracksPromise = axios.get(url, { params: params })
      params.page_size = this.limit
      params.page = this.page
      params.include_channels = true
      try {
        await tracksPromise
        self.nextPage = tracksPromise.data.next
        self.objects = tracksPromise.data.results
        self.count = tracksPromise.data.count
        self.$emit('fetched', tracksPromise.data)
        self.isLoading = false
      } catch (e) {
        self.isLoading = false
        self.errors = e.backendErrors
      }
    },
    updatePage: function (page) {
      this.$emit('page-changed', page)
    }
  }
}
</script>
