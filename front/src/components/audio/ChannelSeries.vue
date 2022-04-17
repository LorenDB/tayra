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
    <template v-if="isPodcast">
      <channel-serie-card
        v-for="serie in objects"
        :key="serie.id"
        :serie="serie"
      />
    </template>
    <div
      v-else
      class="ui app-cards cards"
    >
      <album-card
        v-for="album in objects"
        :key="album.id"
        :album="album"
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
        @refresh="fetchData('albums/')"
      >
        <p>
          <translate translate-context="Content/Channels/*">
            You may need to subscribe to this channel to see its contents.
          </translate>
        </p>
      </empty-state>
    </template>
  </div>
</template>

<script>
import { clone } from 'lodash-es'
import axios from 'axios'
import ChannelSerieCard from '@/components/audio/ChannelSerieCard.vue'
import AlbumCard from '@/components/audio/album/Card.vue'

export default {
  components: {
    ChannelSerieCard,
    AlbumCard
  },
  props: {
    filters: { type: Object, required: true },
    isPodcast: { type: Boolean, default: true },
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
    this.fetchData('albums/')
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
      }, error => {
        self.isLoading = false
        self.errors = error.backendErrors
      })
    }
  }
}
</script>
