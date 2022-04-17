<template>
  <div>
    <slot />
    <div class="ui hidden divider" />
    <div
      v-if="isLoading"
      class="ui inverted active dimmer"
    >
      <div class="ui loader" />
    </div>
    <podcast-table
      v-if="isPodcast"
      :default-cover="defaultCover"
      :is-podcast="isPodcast"
      :show-art="true"
      :show-position="false"
      :tracks="objects"
      :show-artist="false"
      :show-album="false"
      :paginate-results="true"
      :total="count"
      :page="page"
      :paginate-by="limit"
      @page-changed="updatePage"
    />
    <track-table
      v-else
      :default-cover="defaultCover"
      :is-podcast="isPodcast"
      :show-art="true"
      :show-position="false"
      :tracks="objects"
      :show-artist="false"
      :show-album="false"
      :paginate-results="true"
      :total="count"
      :page="page"
      :paginate-by="limit"
      :filters="filters"
      @page-changed="updatePage"
    />
    <template v-if="!isLoading && objects.length === 0">
      <empty-state
        :refresh="true"
        @refresh="fetchData('tracks/')"
      >
        <p>
          <translate translate-context="Content/Channels/*">
            You may need to subscribe to this channel to see its content.
          </translate>
        </p>
      </empty-state>
    </template>
  </div>
</template>

<script>
import { clone } from 'lodash-es'
import axios from 'axios'
import PodcastTable from '@/components/audio/podcast/Table.vue'
import TrackTable from '@/components/audio/track/Table.vue'

export default {
  components: {
    PodcastTable,
    TrackTable
  },
  props: {
    filters: { type: Object, required: true },
    limit: { type: Number, default: 10 },
    defaultCover: { type: Object, default: () => ({}) },
    isPodcast: { type: Boolean, required: true }
  },
  data () {
    return {
      objects: [],
      count: 0,
      isLoading: false,
      errors: [],
      nextPage: null,
      page: 1
    }
  },
  watch: {
    page () {
      this.fetchData('tracks/')
    }
  },
  created () {
    this.fetchData('tracks/')
  },
  methods: {
    async fetchData (url) {
      if (!url) {
        return
      }
      this.isLoading = true
      const self = this
      const params = clone(this.filters)
      params.page_size = this.limit
      params.page = this.page
      params.include_channels = true
      try {
        const channelsPromise = await axios.get(url, { params: params })
        self.nextPage = channelsPromise.data.next
        self.objects = channelsPromise.data.results
        self.count = channelsPromise.data.count
        self.$emit('fetched', channelsPromise.data)
        self.isLoading = false
      } catch (e) {
        self.isLoading = false
        self.errors = e.backendErrors
      }
    },
    updatePage: function (page) {
      this.page = page
    }
  }
}
</script>
