<template>
  <div v-if="object">
    <div
      v-if="contentFilter"
      class="ui small text container"
    >
      <div class="ui hidden divider" />
      <div class="ui message">
        <p>
          <translate translate-context="Content/Artist/Paragraph">
            You are currently hiding content related to this artist.
          </translate>
        </p>
        <router-link
          class="right floated"
          :to="{name: 'settings'}"
        >
          <translate translate-context="Content/Moderation/Link">
            Review my filters
          </translate>
        </router-link>
        <button
          class="ui basic tiny button"
          @click="$store.dispatch('moderation/deleteContentFilter', contentFilter.uuid)"
        >
          <translate translate-context="Content/Moderation/Button.Label">
            Remove filter
          </translate>
        </button>
      </div>
    </div>
    <section
      v-if="isLoadingAlbums"
      class="ui vertical stripe segment"
    >
      <div :class="['ui', 'centered', 'active', 'inline', 'loader']" />
    </section>
    <section
      v-else-if="albums && albums.length > 0"
      class="ui vertical stripe segment"
    >
      <h2>
        <translate translate-context="Content/Artist/Title">
          Albums by this artist
        </translate>
      </h2>
      <div class="ui cards app-cards">
        <album-card
          v-for="album in allAlbums"
          :key="album.id"
          :album="album"
        />
      </div>
      <div class="ui hidden divider" />
      <button
        v-if="nextAlbumsUrl && loadMoreAlbumsUrl"
        :class="['ui', {loading: isLoadingMoreAlbums}, 'button']"
        @click="loadMoreAlbums(loadMoreAlbumsUrl)"
      >
        <translate translate-context="Content/*/Button.Label">
          Load more…
        </translate>
      </button>
    </section>
    <section
      v-if="tracks.length > 0"
      class="ui vertical stripe segment"
    >
      <track-table
        :is-artist="true"
        :show-position="false"
        :track-only="true"
        :tracks="tracks.slice(0,5)"
      >
        <template slot="header">
          <h2>
            <translate translate-context="Content/Artist/Title">
              New tracks by this artist
            </translate>
          </h2>
          <div class="ui hidden divider" />
        </template>
      </track-table>
    </section>
    <section class="ui vertical stripe segment">
      <h2>
        <translate translate-context="Content/*/Title/Noun">
          User libraries
        </translate>
      </h2>
      <library-widget
        :url="'artists/' + object.id + '/libraries/'"
        @loaded="$emit('libraries-loaded', $event)"
      >
        <translate
          slot="subtitle"
          translate-context="Content/Artist/Paragraph"
        >
          This artist is present in the following libraries:
        </translate>
      </library-widget>
    </section>
  </div>
</template>

<script>
import axios from 'axios'
import AlbumCard from '~/components/audio/album/Card.vue'
import TrackTable from '~/components/audio/track/Table.vue'
import LibraryWidget from '~/components/federation/LibraryWidget.vue'

export default {
  components: {
    AlbumCard,
    TrackTable,
    LibraryWidget
  },
  props: {
    object: { type: Object, required: true },
    tracks: { type: Array, required: true },
    albums: { type: Array, required: true },
    isLoadingAlbums: { type: Boolean, required: true },
    nextTracksUrl: { type: String, default: null },
    nextAlbumsUrl: { type: String, default: null }
  },
  data () {
    return {
      loadMoreAlbumsUrl: this.nextAlbumsUrl,
      additionalAlbums: [],
      isLoadingMoreAlbums: false
    }
  },
  computed: {
    contentFilter () {
      return this.$store.getters['moderation/artistFilters']().filter((e) => {
        return e.target.id === this.object.id
      })[0]
    },
    allAlbums () {
      return this.albums.concat(this.additionalAlbums)
    }
  },
  methods: {
    loadMoreAlbums (url) {
      const self = this
      self.isLoadingMoreAlbums = true
      axios.get(url).then((response) => {
        self.additionalAlbums = self.additionalAlbums.concat(response.data.results)
        self.loadMoreAlbumsUrl = response.data.next
        self.isLoadingMoreAlbums = false
      }, () => {
        self.isLoadingMoreAlbums = false
      })
    }
  }
}
</script>
