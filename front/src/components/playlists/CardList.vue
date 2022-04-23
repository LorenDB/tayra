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

<script>

import PlaylistCard from '~/components/playlists/Card.vue'

export default {
  components: {
    PlaylistCard
  },
  props: { playlists: { type: Array, required: true } }
}
</script>
