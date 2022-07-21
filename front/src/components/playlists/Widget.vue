<template>
  <div>
    <h3
      v-if="!!$slots.title"
      class="ui header"
    >
      <slot name="title" />
    </h3>
    <div
      v-if="isLoading"
      class="ui inverted active dimmer"
    >
      <div class="ui loader" />
    </div>
    <div
      v-if="playlistsExist"
      class="ui cards app-cards"
    >
      <playlist-card
        v-for="playlist in objects"
        :key="playlist.id"
        :playlist="playlist"
      />
    </div>
    <div
      v-else
      class="ui placeholder segment"
    >
      <div class="ui icon header">
        <i class="list icon" />
        <translate translate-context="Content/Home/Placeholder">
          No playlists have been created yet
        </translate>
      </div>
      <button
        v-if="$store.state.auth.authenticated"
        class="ui success icon labeled button"
        @click="$store.commit('playlists/chooseTrack', null)"
      >
        <i class="list icon" />
        <translate translate-context="Content/Home/CreatePlaylist">
          Create Playlist
        </translate>
      </button>
    </div>
    <template v-if="nextPage">
      <div class="ui hidden divider" />
      <button
        v-if="nextPage"
        :class="['ui', 'basic', 'button']"
        @click="fetchData(nextPage)"
      >
        <translate translate-context="*/*/Button,Label">
          Show more
        </translate>
      </button>
    </template>
  </div>
</template>

<script>
import { clone } from 'lodash-es'
import axios from 'axios'
import PlaylistCard from '~/components/playlists/Card.vue'

export default {
  components: {
    PlaylistCard
  },
  props: {
    filters: { type: Object, required: true },
    url: { type: String, required: true }
  },
  data () {
    return {
      objects: [],
      limit: this.filters.limit || 3,
      isLoading: false,
      errors: null,
      previousPage: null,
      nextPage: null
    }
  },
  computed: {
    playlistsExist: function () {
      return this.objects.length > 0
    }
  },
  watch: {
    offset () {
      this.fetchData()
    },
    '$store.state.moderation.lastUpdate': function () {
      this.fetchData(this.url)
    }
  },
  created () {
    this.fetchData(this.url)
  },
  methods: {
    fetchData (url) {
      if (!url) {
        return
      }
      this.isLoading = true
      const self = this
      const params = clone(this.filters)
      params.page_size = this.limit
      params.offset = this.offset
      axios.get(url, { params }).then((response) => {
        self.previousPage = response.data.previous
        self.nextPage = response.data.next
        self.isLoading = false
        self.objects = [...self.objects, ...response.data.results]
      }, error => {
        self.isLoading = false
        self.errors = error.backendErrors
      })
    },
    updateOffset (increment) {
      if (increment) {
        this.offset += this.limit
      } else {
        this.offset = Math.max(this.offset - this.limit, 0)
      }
    }
  }
}
</script>
