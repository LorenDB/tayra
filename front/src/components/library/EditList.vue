<template>
  <div class="wrapper">
    <h3 class="ui header">
      <slot />
    </h3>
    <slot
      v-if="!isLoading && objects.length === 0"
      name="empty-state"
    />
    <button
      v-if="nextPage || previousPage"
      :disabled="!previousPage || null"
      :class="['ui', {disabled: !previousPage}, 'circular', 'icon', 'basic', 'button']"
      @click="fetchData(previousPage)"
    >
      <i :class="['ui', 'angle left', 'icon']" />
    </button>
    <button
      v-if="nextPage || previousPage"
      :disabled="!nextPage || null"
      :class="['ui', {disabled: !nextPage}, 'circular', 'icon', 'basic', 'button']"
      @click="fetchData(nextPage)"
    >
      <i :class="['ui', 'angle right', 'icon']" />
    </button>
    <div class="ui hidden divider" />
    <div
      v-if="isLoading"
      class="ui inverted active dimmer"
    >
      <div class="ui loader" />
    </div>
    <edit-card
      v-for="obj in objects"
      :key="obj.uuid"
      :obj="obj"
      :current-state="currentState"
      @updated="fetchData(url)"
      @deleted="fetchData(url)"
    />
  </div>
</template>

<script>
import { clone } from 'lodash-es'
import axios from 'axios'

import EditCard from '~/components/library/EditCard.vue'

export default {
  components: {
    EditCard
  },
  props: {
    url: { type: String, required: true },
    filters: { type: Object, required: false, default: () => { return {} } },
    currentState: { type: Object, required: false, default: () => { return { } } }
  },
  data () {
    return {
      objects: [],
      limit: 5,
      isLoading: false,
      errors: null,
      previousPage: null,
      nextPage: null
    }
  },
  watch: {
    filters: {
      handler () {
        this.fetchData(this.url)
      },
      deep: true
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
      axios.get(url, { params: params }).then((response) => {
        self.previousPage = response.data.previous
        self.nextPage = response.data.next
        self.isLoading = false
        self.objects = response.data.results
      }, error => {
        self.isLoading = false
        self.errors = error.backendErrors
      })
    }
  }
}
</script>
