<script setup lang="ts">
import type { Artist } from '~/types'

import { computed } from 'vue'

interface Props {
  artist: Artist
}

const props = defineProps<Props>()

const route = computed(() => props.artist.channel
  ? { name: 'channels.detail', params: { id: props.artist.channel.uuid } }
  : { name: 'library.artists.detail', params: { id: props.artist.id } }
)
</script>

<template>
  <router-link
    class="artist-label ui image label"
    :to="route"
  >
    <img
      v-if="artist.cover && artist.cover.urls.original"
      v-lazy="$store.getters['instance/absoluteUrl'](artist.cover.urls.medium_square_crop)"
      alt=""
      :class="[{circular: artist.content_category != 'podcast'}]"
    >
    <i
      v-else
      :class="[artist.content_category != 'podcast' ? 'circular' : 'bordered', 'inverted violet users icon']"
    />
    {{ artist.name }}
  </router-link>
</template>
