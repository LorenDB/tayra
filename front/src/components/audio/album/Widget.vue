<script setup lang="ts">
import type { Album } from '~/types'

import axios from 'axios'
import { reactive, ref, watch } from 'vue'
import { useStore } from '~/store'

import AlbumCard from '~/components/audio/album/Card.vue'

interface Props {
  filters: Record<string, string>
  showCount?: boolean
  search?: boolean
  limit?: number
}

const props = withDefaults(defineProps<Props>(), {
  showCount: false,
  search: false,
  limit: 12
})

const store = useStore()

const query = ref('')
const albums = reactive([] as Album[])
const count = ref(0)
const nextPage = ref()

const isLoading = ref(false)
const fetchData = async (url = 'albums/') => {
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
    albums.push(...response.data.results)
  } catch (error) {
    // TODO (wvffle): Handle error
  }

  isLoading.value = false
}

const performSearch = () => {
  albums.length = 0
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
