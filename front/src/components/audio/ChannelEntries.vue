<script setup lang="ts">
import type { Cover, Track, BackendResponse, BackendError } from '~/types'

import { clone } from 'lodash-es'
import { ref, watch } from 'vue'

import axios from 'axios'
import PodcastTable from '~/components/audio/podcast/Table.vue'
import TrackTable from '~/components/audio/track/Table.vue'

interface Events {
  (e: 'fetched', data: BackendResponse<Track[]>): void
}

interface Props {
  filters: object
  limit?: number
  defaultCover: Cover | null
  isPodcast: boolean
}

const emit = defineEmits<Events>()
const props = withDefaults(defineProps<Props>(), {
  limit: 10,
  defaultCover: null
})

const channels = ref([] as Track[])
const nextPage = ref()
const page = ref(1)
const count = ref(0)
const errors = ref([] as string[])

const isLoading = ref(false)
const fetchData = async () => {
  isLoading.value = true

  const params = {
    ...clone(props.filters),
    page_size: props.limit,
    page: page.value,
    include_channels: true
  }

  try {
    const response = await axios.get('tracks/', { params })
    nextPage.value = response.data.next
    channels.value = response.data.results
    count.value = response.data.count
    emit('fetched', response.data)
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}

watch(page, fetchData, { immediate: true })
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
    <podcast-table
      v-if="isPodcast"
      v-model:page="page"
      :default-cover="defaultCover"
      :is-podcast="isPodcast"
      :show-art="true"
      :show-position="false"
      :tracks="channels"
      :show-artist="false"
      :show-album="false"
      :paginate-results="true"
      :total="count"
      :paginate-by="limit"
    />
    <track-table
      v-else
      v-model:page="page"
      :default-cover="defaultCover"
      :is-podcast="isPodcast"
      :show-art="true"
      :show-position="false"
      :tracks="channels"
      :show-artist="false"
      :show-album="false"
      :paginate-results="true"
      :total="count"
      :paginate-by="limit"
      :filters="filters"
    />
    <template v-if="!isLoading && channels.length === 0">
      <empty-state
        :refresh="true"
        @refresh="fetchData()"
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
