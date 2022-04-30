<template>
  <main
    :key="$router.currentRoute.value.name"
    v-title="labels.title"
  >
    <section class="ui vertical stripe segment">
      <div class="ui stackable three column grid">
        <div class="column">
          <track-widget
            :url="'history/listenings/'"
            :filters="{scope: scope, ordering: '-creation_date'}"
          >
            <template slot="title">
              <translate translate-context="Content/Home/Title">
                Recently listened
              </translate>
            </template>
          </track-widget>
        </div>
        <div class="column">
          <track-widget
            :url="'favorites/tracks/'"
            :filters="{scope: scope, ordering: '-creation_date'}"
          >
            <template slot="title">
              <translate translate-context="Content/Home/Title">
                Recently favorited
              </translate>
            </template>
          </track-widget>
        </div>
        <div class="column">
          <playlist-widget
            :url="'playlists/'"
            :filters="{scope: scope, playable: true, ordering: '-modification_date'}"
          >
            <template slot="title">
              <translate translate-context="*/*/*">
                Playlists
              </translate>
            </template>
          </playlist-widget>
        </div>
      </div>
      <div class="ui section hidden divider" />
      <div class="ui stackable one column grid">
        <div class="column">
          <album-widget :filters="{scope: scope, playable: true, ordering: '-creation_date'}">
            <template slot="title">
              <translate translate-context="Content/Home/Title">
                Recently added
              </translate>
            </template>
          </album-widget>
        </div>
      </div>
      <template v-if="scope === 'all'">
        <h3 class="ui header">
          <translate translate-context="*/*/*">
            New channels
          </translate>
        </h3>
        <channels-widget
          :show-modification-date="true"
          :limit="12"
          :filters="{ordering: '-creation_date', external: 'false'}"
        />
      </template>
    </section>
  </main>
</template>

<script>
import axios from 'axios'
import logger from '~/logging'
import ChannelsWidget from '~/components/audio/ChannelsWidget.vue'
import TrackWidget from '~/components/audio/track/Widget.vue'
import AlbumWidget from '~/components/audio/album/Widget.vue'
import PlaylistWidget from '~/components/playlists/Widget.vue'

const ARTISTS_URL = 'artists/'

export default {
  name: 'Library',
  components: {
    TrackWidget,
    AlbumWidget,
    PlaylistWidget,
    ChannelsWidget
  },
  props: {
    scope: { type: String, default: 'all' }
  },
  data () {
    return {
      artists: [],
      isLoadingArtists: false
    }
  },
  computed: {
    labels () {
      return {
        title: this.$pgettext('Head/Home/Title', 'Library')
      }
    }
  },
  created () {
    this.fetchArtists()
  },
  methods: {
    fetchArtists () {
      const self = this
      this.isLoadingArtists = true
      const params = {
        ordering: '-creation_date',
        playable: true
      }
      const url = ARTISTS_URL
      logger.default.time('Loading latest artists')
      axios.get(url, { params: params }).then(response => {
        self.artists = response.data.results
        logger.default.timeEnd('Loading latest artists')
        self.isLoadingArtists = false
      })
    }
  }
}
</script>
