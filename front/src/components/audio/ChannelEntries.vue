<template>
  <div>
    <slot></slot>
    <div class="ui hidden divider"></div>
    <div v-if="isLoading" class="ui inverted active dimmer">
      <div class="ui loader"></div>
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
      @page-changed="updatePage"
      :page="page"
      :paginate-by="limit"></podcast-table>
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
      @page-changed="updatePage"
      :page="page"
      :paginate-by="limit"></track-table>
    <template v-if="!isLoading && objects.length === 0">
      <empty-state @refresh="fetchData('tracks/')" :refresh="true">
        <p>
          <translate translate-context="Content/Channels/*">You may need to subscribe to this channel to see its content.</translate>
        </p>
      </empty-state>
    </template>
  </div>
</template>

<script>
import _ from '@/lodash'
import axios from 'axios'
import PodcastTable from '@/components/audio/podcast/Table'
import TrackTable from '@/components/audio/track/Table'

export default {
  props: {
    filters: {type: Object, required: true},
    limit: {type: Number, default: 10},
    defaultCover: {type: Object},
    isPodcast: {type: Boolean, required: true},
  },
  components: {
    PodcastTable,
    TrackTable,
  },
  data () {
    return {
      objects: [],
      count: 0,
      isLoading: false,
      errors: null,
      nextPage: null,
      page: 1
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
      let self = this
      let params = _.clone(this.filters)
      params.page_size = this.limit
      params.page = this.page
      params.include_channels = true
      try {
      let channelsPromise = await axios.get(url, {params: params})
      self.nextPage = channelsPromise.data.next
      self.objects = channelsPromise.data.results
      self.count = channelsPromise.data.count
      self.$emit('fetched', channelsPromise.data)
      self.isLoading = false
      } catch(e) {
        self.isLoading = false
        self.errors = error.backendErrors
      }
    },
    updatePage: function(page) {
      this.page = page
    }
  },
  watch: {
    page() {
      this.fetchData('tracks/')
    }
  }
}
</script>
