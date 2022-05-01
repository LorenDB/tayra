<template>
  <div class="wrapper">
    <h3
      v-if="!!$slots.title"
      class="ui header"
    >
      <slot name="title" />
    </h3>
    <p
      v-if="!isLoading && libraries.length > 0"
      class="ui subtitle"
    >
      <slot />
    </p>
    <p
      v-if="!isLoading && libraries.length === 0"
      class="ui subtitle"
    >
      <translate translate-context="Content/Federation/Paragraph">
        No matching library.
      </translate>
    </p>
    <div class="ui hidden divider" />
    <div class="ui cards">
      <div
        v-if="isLoading"
        class="ui inverted active dimmer"
      >
        <div class="ui loader" />
      </div>
      <library-card
        v-for="library in libraries"
        :key="library.uuid"
        :display-scan="false"
        :display-follow="$store.state.auth.authenticated && library.actor.full_username != $store.state.auth.fullUsername"
        :initial-library="library"
        :display-copy-fid="true"
      />
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
import LibraryCard from '~/views/content/remote/Card.vue'

export default {
  components: {
    LibraryCard
  },
  props: {
    url: { type: String, required: true }
  },
  data () {
    return {
      libraries: [],
      limit: 6,
      isLoading: false,
      errors: null,
      previousPage: null,
      nextPage: null
    }
  },
  watch: {
    offset () {
      this.fetchData()
    }
  },
  created () {
    this.fetchData(this.url)
  },
  methods: {
    fetchData (url) {
      this.isLoading = true
      const self = this
      const params = clone({})
      params.page_size = this.limit
      params.offset = this.offset
      axios.get(url, { params: params }).then((response) => {
        self.previousPage = response.data.previous
        self.nextPage = response.data.next
        self.isLoading = false
        self.libraries = [...self.libraries, ...response.data.results]
        self.$emit('loaded', self.libraries)
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
