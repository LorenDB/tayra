<script setup lang="ts">
import type { Playlist } from '~/types'

import PlaylistCard from '~/components/playlists/Card.vue'

interface Props {
  playlists: Playlist[]
}

defineProps<Props>()
</script>

<template>
  <div v-if="playlists.length > 0">
    <div class="ui app-cards cards">
      <playlist-card
        v-for="playlist in playlists"
        :key="playlist.id"
        :playlist="playlist"
      />
    </div>
  </div>
</template>
