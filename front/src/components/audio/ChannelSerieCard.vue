<template>
  <div class="channel-serie-card">
    <div class="two-images">
      <img
        v-if="cover && cover.urls.original"
        v-lazy="$store.getters['instance/absoluteUrl'](cover.urls.medium_square_crop)"
        alt=""
        class="channel-image"
        @click="$router.push({name: 'library.albums.detail', params: {id: serie.id}})"
      >
      <img
        v-else
        alt=""
        class="channel-image"
        src="../../assets/audio/default-cover.png"
        @click="$router.push({name: 'library.albums.detail', params: {id: serie.id}})"
      >
      <img
        v-if="cover && cover.urls.original"
        v-lazy="$store.getters['instance/absoluteUrl'](cover.urls.medium_square_crop)"
        alt=""
        class="channel-image"
        @click="$router.push({name: 'library.albums.detail', params: {id: serie.id}})"
      >
      <img
        v-else
        alt=""
        class="channel-image"
        src="../../assets/audio/default-cover.png"
        @click="$router.push({name: 'library.albums.detail', params: {id: serie.id}})"
      >
    </div>
    <div class="content ellipsis">
      <strong>
        <router-link
          class="discrete link"
          :to="{name: 'library.albums.detail', params: {id: serie.id}}"
        >
          {{ serie.title }}
        </router-link>
      </strong>
      <div class="description">
        <translate
          translate-context="Content/Channel/Paragraph"
          translate-plural="%{ count } episodes"
          :translate-n="serie.tracks_count"
          :translate-params="{count: serie.tracks_count}"
        >
          %{ count } episode
        </translate>
      </div>
    </div>
    <div class="controls">
      <play-button
        :icon-only="true"
        :is-playable="true"
        :button-classes="['ui', 'circular', 'vibrant', 'icon', 'button']"
        :album="serie"
      />
    </div>
  </div>
</template>

<script>
import PlayButton from '~/components/audio/PlayButton.vue'

export default {
  components: {
    PlayButton
  },
  props: { serie: { type: Object, required: true } },
  computed: {
    cover () {
      if (this.serie.cover) {
        return this.serie.cover
      }
      return null
    },
    duration () {
      const uploads = this.serie.uploads.filter((e) => {
        return e.duration
      })
      return uploads[0].duration
    }
  }
}
</script>
