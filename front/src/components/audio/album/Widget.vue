<template>
  <div class="wrapper">
    <h3
      v-if="!!$slots.title"
      class="ui header"
    >
      <slot name="title" />
      <span
        v-if="showCount"
        class="ui tiny circular label"
      >{{ count }}</span>
    </h3>
    <slot />
    <inline-search-bar
      v-if="search"
      v-model="query"
      @search="performSearch"
    />
    <div class="ui hidden divider" />
    <div class="ui app-cards cards">
      <div
        v-if="isLoading"
        class="ui inverted active dimmer"
      >
        <div class="ui loader" />
      </div>
      <album-card
        v-for="album in albums"
        :key="album.id"
        :album="album"
      />
    </div>
    <slot
      v-if="!isLoading && albums.length === 0"
      name="empty-state"
    >
      <empty-state
        :refresh="true"
        @refresh="fetchData"
      />
    </slot>
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
import axios from 'axios'
import AlbumCard from '~/components/audio/album/Card.vue'

export default {
  components: {
    AlbumCard
  },
  props: {
    filters: { type: Object, required: true },
    controls: { type: Boolean, default: true },
    showCount: { type: Boolean, default: false },
    search: { type: Boolean, default: false },
    limit: { type: Number, default: 12 }
  },
  setup () {
    const performSearch = () => {
      this.albums.length = 0
      this.fetchData()
    }

    return { performSearch }
  },
  data () {
    return {
      albums: [],
      count: 0,
      isLoading: false,
      errors: null,
      previousPage: null,
      nextPage: null,
      query: ''
    }
  },
  watch: {
    offset () {
      this.fetchData()
    },
    '$store.state.moderation.lastUpdate': function () {
      this.fetchData()
    }
  },
  created () {
    this.fetchData()
  },
  methods: {
    fetchData (url) {
      url = url || 'albums/'
      this.isLoading = true
      const self = this
      const params = { q: this.query, ...this.filters }
      params.page_size = this.limit
      params.offset = this.offset
      axios.get(url, { params: params }).then((response) => {
        self.previousPage = response.data.previous
        self.nextPage = response.data.next
        self.isLoading = false
        self.albums = [...self.albums, ...response.data.results]
        self.count = response.data.count
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
