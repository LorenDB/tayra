<script setup lang="ts">
import type { Playlist } from '~/types'

import { ref, reactive, watch } from 'vue'
import { useStore } from '~/store'

import axios from 'axios'

import useErrorHandler from '~/composables/useErrorHandler'

import PlaylistCard from '~/components/playlists/Card.vue'

interface Props {
  filters: Record<string, unknown>
  url: string
}

const props = defineProps<Props>()

const store = useStore()

const objects = reactive([] as Playlist[])
const isLoading = ref(false)
const nextPage = ref('')
const fetchData = async (url = props.url) => {
  isLoading.value = true

  try {
    const params = {
      ...props.filters,
      page_size: props.filters.limit ?? 3
    }

    const response = await axios.get(url, { params })
    nextPage.value = response.data.next
    objects.push(...response.data.results)
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoading.value = false
}

watch(
  () => store.state.moderation.lastUpdate,
  () => fetchData(),
  { immediate: true }
)
</script>

<template>
  <div>
    <h3
      v-if="!!$slots.title"
      class="ui header"
    >
      <slot name="title" />
    </h3>
    <div
      v-if="isLoading"
      class="ui inverted active dimmer"
    >
      <div class="ui loader" />
    </div>
    <div
      v-if="objects.length > 0"
      class="ui cards app-cards"
    >
      <playlist-card
        v-for="playlist in objects"
        :key="playlist.id"
        :playlist="playlist"
      />
    </div>
    <div
      v-else
      class="ui placeholder segment"
    >
      <div class="ui icon header">
        <i class="list icon" />
        <translate translate-context="Content/Home/Placeholder">
          No playlists have been created yet
        </translate>
      </div>
      <button
        v-if="$store.state.auth.authenticated"
        class="ui success icon labeled button"
        @click="$store.commit('playlists/chooseTrack', null)"
      >
        <i class="list icon" />
        <translate translate-context="Content/Home/CreatePlaylist">
          Create Playlist
        </translate>
      </button>
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
