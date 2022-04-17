<template>
  <div>
    <slot />
    <div class="ui hidden divider" />
    <div class="ui app-cards cards">
      <div
        v-if="isLoading"
        class="ui inverted active dimmer"
      >
        <div class="ui loader" />
      </div>
      <channel-card
        v-for="object in objects"
        :key="object.uuid"
        :object="object"
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
    <template v-if="!isLoading && objects.length === 0">
      <empty-state
        :refresh="true"
        @refresh="fetchData('channels/')"
      />
    </template>
  </div>
</template>

<script>
import { clone } from 'lodash-es'
import axios from 'axios'
import ChannelCard from '@/components/audio/ChannelCard.vue'

export default {
  components: {
    ChannelCard
  },
  props: {
    filters: { type: Object, required: true },
    limit: { type: Number, default: 5 }
  },
  data () {
    return {
      objects: [],
      count: 0,
      isLoading: false,
      errors: null,
      nextPage: null
    }
  },
  created () {
    this.fetchData('channels/')
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
      params.include_channels = true
      axios.get(url, { params: params }).then((response) => {
        self.nextPage = response.data.next
        self.isLoading = false
        self.objects = self.objects.concat(response.data.results)
        self.count = response.data.count
        self.$emit('fetched', response.data)
      }, error => {
        self.isLoading = false
        self.errors = error.backendErrors
      })
    }
  }
}
</script>
