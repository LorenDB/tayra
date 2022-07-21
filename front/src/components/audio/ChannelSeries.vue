<script setup lang="ts">
import type { BackendError, Album } from '~/types'

import { clone } from 'lodash-es'
import { ref, reactive } from 'vue'

import axios from 'axios'
import ChannelSerieCard from '~/components/audio/ChannelSerieCard.vue'
import AlbumCard from '~/components/audio/album/Card.vue'

interface Props {
  filters: object
  isPodcast?: boolean
  limit?: number
}

const props = withDefaults(defineProps<Props>(), {
  isPodcast: true,
  limit: 5
})

const isLoading = ref(false)
const errors = ref([] as string[])

const albums = reactive([] as Album[])
const nextPage = ref()
const count = ref(0)

const fetchData = async (url = 'albums/') => {
  isLoading.value = true

  try {
    const params = {
      ...clone(props.filters),
      page_size: props.limit,
      include_channels: true
    }

    const response = await axios.get(url, { params })
    nextPage.value = response.data.next
    count.value = response.data.count
    albums.push(...response.data.results)
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}

fetchData()
</script>

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
        v-for="serie in albums"
        :key="serie.id"
        :serie="serie"
      />
    </template>
    <div
      v-else
      class="ui app-cards cards"
    >
      <album-card
        v-for="album in albums"
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
    <template v-if="!isLoading && albums.length === 0">
      <empty-state
        :refresh="true"
        @refresh="fetchData()"
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
