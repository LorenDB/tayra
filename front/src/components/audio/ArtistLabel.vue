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

<script>

export default {
  props: {
    artist: { type: Object, required: true }
  },
  computed: {
    route () {
      if (this.artist.channel) {
        return { name: 'channels.detail', params: { id: this.artist.channel.uuid } }
      }
      return { name: 'library.artists.detail', params: { id: this.artist.id } }
    }
  }
}
</script>
