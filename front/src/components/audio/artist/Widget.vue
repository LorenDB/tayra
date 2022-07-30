<script setup lang="ts">
import type { Artist } from '~/types'

import axios from 'axios'
import { reactive, ref, watch } from 'vue'
import { useStore } from '~/store'

import ArtistCard from '~/components/audio/artist/Card.vue'

interface Props {
  filters: Record<string, string>
  search?: boolean
  header?: boolean
  limit?: number
}

const props = withDefaults(defineProps<Props>(), {
  search: false,
  header: true,
  limit: 12
})

const store = useStore()

const query = ref('')
const artists = reactive([] as Artist[])
const count = ref(0)
const nextPage = ref()

const isLoading = ref(false)
const fetchData = async (url = 'artists/') => {
  isLoading.value = true

  try {
    const params = {
      q: query.value,
      ...props.filters,
      page_size: props.limit
    }

    const response = await axios.get(url, { params })
    nextPage.value = response.data.next
    count.value = response.data.count
    artists.push(...response.data.results)
  } catch (error) {
    // TODO (wvffle): Handle error
  }

  isLoading.value = false
}

const performSearch = () => {
  artists.length = 0
  fetchData()
}

watch(
  () => store.state.moderation.lastUpdate,
  () => fetchData(),
  { immediate: true }
)
</script>

<template>
  <div class="wrapper">
    <h3
      v-if="header"
      class="ui header"
    >
      <slot name="title" />
      <span class="ui tiny circular label">{{ count }}</span>
    </h3>
    <inline-search-bar
      v-if="search"
      v-model="query"
      @search="performSearch"
    />
    <div class="ui hidden divider" />
    <div class="ui five app-cards cards">
      <div
        v-if="isLoading"
        class="ui inverted active dimmer"
      >
        <div class="ui loader" />
      </div>
      <artist-card
        v-for="artist in artists"
        :key="artist.id"
        :artist="artist"
      />
    </div>
    <slot
      v-if="!isLoading && artists.length === 0"
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
