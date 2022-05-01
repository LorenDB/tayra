<template>
  <main v-title="labels.title">
    <section class="ui vertical stripe segment">
      <h2 class="ui header">
        <span class="ui circular huge hashtag label component-label">
          {{ labels.title }}
        </span>
      </h2>
      <radio-button
        type="tag"
        :object-id="id"
      />
      <router-link
        v-if="$store.state.auth.availablePermissions['library']"
        class="ui right floated button"
        :to="{name: 'manage.library.tags.detail', params: {id: id}}"
      >
        <i class="wrench icon" />
        <translate translate-context="Content/Moderation/Link">
          Open in moderation interface
        </translate>
      </router-link>

      <div class="ui hidden divider" />
      <div class="ui row">
        <artist-widget
          :key="'artist' + id"
          :controls="false"
          :filters="{playable: true, ordering: '-creation_date', tag: id, include_channels: 'false'}"
        >
          <template #title>
            <router-link :to="{name: 'library.artists.browse', query: {tag: id}}">
              <translate translate-context="*/*/*/Noun">
                Artists
              </translate>
            </router-link>
          </template>
        </artist-widget>
        <div class="ui hidden divider" />
        <div class="ui hidden divider" />
        <h3 class="ui header">
          <translate translate-context="*/*/*">
            Channels
          </translate>
        </h3>
        <channels-widget
          :key="'channels' + id"
          :show-modification-date="true"
          :limit="12"
          :filters="{tag: id, ordering: '-creation_date'}"
        />
        <div class="ui hidden divider" />
        <div class="ui hidden divider" />
        <album-widget
          :key="'album' + id"
          :show-count="true"
          :controls="false"
          :filters="{playable: true, ordering: '-creation_date', tag: id}"
        >
          <template #title>
            <router-link :to="{name: 'library.albums.browse', query: {tag: id}}">
              <translate translate-context="*/*/*">
                Albums
              </translate>
            </router-link>
          </template>
        </album-widget>
        <div class="ui hidden divider" />
        <div class="ui hidden divider" />
        <track-widget
          :key="'track' + id"
          :show-count="true"
          :limit="12"
          item-classes="track-item inline"
          :url="'/tracks/'"
          :is-activity="false"
          :filters="{playable: true, ordering: '-creation_date', tag: id}"
        >
          <template #title>
            <translate translate-context="*/*/*">
              Tracks
            </translate>
          </template>
        </track-widget>
        <div class="ui clearing hidden divider" />
      </div>
    </section>
  </main>
</template>

<script>
import ChannelsWidget from '~/components/audio/ChannelsWidget.vue'
import TrackWidget from '~/components/audio/track/Widget.vue'
import AlbumWidget from '~/components/audio/album/Widget.vue'
import ArtistWidget from '~/components/audio/artist/Widget.vue'
import RadioButton from '~/components/radios/Button.vue'

export default {
  components: {
    ArtistWidget,
    AlbumWidget,
    TrackWidget,
    RadioButton,
    ChannelsWidget
  },
  props: {
    id: { type: String, required: true }
  },
  computed: {
    labels () {
      const title = `#${this.id}`
      return {
        title
      }
    },
    isAuthenticated () {
      return this.$store.state.auth.authenticated
    },
    hasFavorites () {
      return this.$store.state.favorites.count > 0
    }
  }
}
</script>
