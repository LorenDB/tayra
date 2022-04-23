<template>
  <div class="app-card card">
    <router-link
      class="discrete link"
      :to="{name: 'library.artists.detail', params: {id: artist.id}}"
    >
      <div
        v-lazy:background-image="imageUrl"
        :class="['ui', 'head-image', 'circular', 'image', {'default-cover': !cover || !cover.urls.original}]"
      >
        <play-button
          :icon-only="true"
          :is-playable="artist.is_playable"
          :button-classes="['ui', 'circular', 'large', 'vibrant', 'icon', 'button']"
          :artist="artist"
        />
      </div>
    </router-link>
    <div class="content">
      <strong>
        <router-link
          class="discrete link"
          :to="{name: 'library.artists.detail', params: {id: artist.id}}"
        >
          {{ artist.name|truncate(30) }}
        </router-link>
      </strong>

      <tags-list
        label-classes="tiny"
        :truncate-size="20"
        :limit="2"
        :show-more="false"
        :tags="artist.tags"
      />
    </div>
    <div class="extra content">
      <translate
        v-if="artist.content_category === 'music'"
        translate-context="*/*/*"
        :translate-params="{count: artist.tracks_count}"
        :translate-n="artist.tracks_count"
        translate-plural="%{ count } tracks"
      >
        %{ count } track
      </translate>
      <translate
        v-else
        translate-context="*/*/*"
        :translate-params="{count: artist.tracks_count}"
        :translate-n="artist.tracks_count"
        translate-plural="%{ count } episodes"
      >
        %{ count } episode
      </translate>
      <play-button
        class="right floated basic icon"
        :dropdown-only="true"
        :is-playable="artist.is_playable"
        :dropdown-icon-classes="['ellipsis', 'horizontal', 'large really discrete']"
        :artist="artist"
      />
    </div>
  </div>
</template>

<script>
import PlayButton from '~/components/audio/PlayButton.vue'
import TagsList from '~/components/tags/List.vue'

export default {
  components: {
    PlayButton,
    TagsList
  },
  props: { artist: { type: Object, required: true } },
  data () {
    return {
      initialAlbums: 30,
      showAllAlbums: true
    }
  },
  computed: {
    imageUrl () {
      const cover = this.cover
      if (cover && cover.urls.original) {
        return this.$store.getters['instance/absoluteUrl'](cover.urls.medium_square_crop)
      }
      return null
    },
    cover () {
      if (this.artist.cover && this.artist.cover.urls.original) {
        return this.artist.cover
      }
      return this.artist.albums.map((a) => {
        return a.cover
      }).filter((c) => {
        return c && c.urls.original
      })[0]
    }
  }
}
</script>
