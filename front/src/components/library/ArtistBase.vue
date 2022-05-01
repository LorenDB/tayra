<template>
  <main v-title="labels.title">
    <div
      v-if="isLoading"
      class="ui vertical segment"
    >
      <div :class="['ui', 'centered', 'active', 'inline', 'loader']" />
    </div>
    <template v-if="object && !isLoading">
      <section
        v-title="object.name"
        :class="['ui', 'head', {'with-background': cover}, 'vertical', 'center', 'aligned', 'stripe', 'segment']"
        :style="headerStyle"
      >
        <div class="segment-content">
          <h2 class="ui center aligned icon header">
            <i class="circular inverted users violet icon" />
            <div class="content">
              {{ object.name }}
              <div
                v-if="albums"
                class="sub header"
              >
                <translate
                  translate-context="Content/Artist/Paragraph"
                  tag="div"
                  translate-plural="%{ count } tracks in %{ albumsCount } albums"
                  :translate-n="totalTracks"
                  :translate-params="{count: totalTracks, albumsCount: totalAlbums}"
                >
                  %{ count } track in %{ albumsCount } albums
                </translate>
              </div>
            </div>
          </h2>
          <tags-list
            v-if="object.tags && object.tags.length > 0"
            :tags="object.tags"
          />
          <div class="ui hidden divider" />
          <div class="header-buttons">
            <div class="ui buttons">
              <radio-button
                type="artist"
                :object-id="String(object.id)"
              />
            </div>
            <div class="ui buttons">
              <play-button
                :is-playable="isPlayable"
                class="vibrant"
                :artist="object"
              >
                <translate translate-context="Content/Artist/Button.Label/Verb">
                  Play all albums
                </translate>
              </play-button>
            </div>

            <modal
              v-if="publicLibraries.length > 0"
              v-model:show="showEmbedModal"
            >
              <h4 class="header">
                <translate translate-context="Popup/Artist/Title/Verb">
                  Embed this artist work on your website
                </translate>
              </h4>
              <div class="scrolling content">
                <div class="description">
                  <embed-wizard
                    :id="object.id"
                    type="artist"
                  />
                </div>
              </div>
              <div class="actions">
                <button class="ui deny button">
                  <translate translate-context="*/*/Button.Label/Verb">
                    Cancel
                  </translate>
                </button>
              </div>
            </modal>
            <div class="ui buttons">
              <button
                class="ui button"
                @click="$refs.dropdown.click()"
              >
                <translate translate-context="*/*/Button.Label/Noun">
                  More…
                </translate>
              </button>
              <button
                ref="dropdown"
                v-dropdown
                class="ui floating dropdown icon button"
              >
                <i class="dropdown icon" />
                <div class="menu">
                  <a
                    v-if="domain != $store.getters['instance/domain']"
                    :href="object.fid"
                    target="_blank"
                    class="basic item"
                  >
                    <i class="external icon" />
                    <translate
                      :translate-params="{domain: domain}"
                      translate-context="Content/*/Button.Label/Verb"
                    >View on %{ domain }</translate>
                  </a>

                  <button
                    v-if="publicLibraries.length > 0"
                    role="button"
                    class="basic item"
                    @click.prevent="showEmbedModal = !showEmbedModal"
                  >
                    <i class="code icon" />
                    <translate translate-context="Content/*/Button.Label/Verb">
                      Embed
                    </translate>
                  </button>
                  <a
                    :href="wikipediaUrl"
                    target="_blank"
                    rel="noreferrer noopener"
                    class="basic item"
                  >
                    <i class="wikipedia w icon" />
                    <translate translate-context="Content/*/Button.Label/Verb">Search on Wikipedia</translate>
                  </a>
                  <a
                    v-if="musicbrainzUrl"
                    :href="musicbrainzUrl"
                    target="_blank"
                    rel="noreferrer noopener"
                    class="basic item"
                  >
                    <i class="external icon" />
                    <translate translate-context="Content/*/*/Clickable, Verb">View on MusicBrainz</translate>
                  </a>
                  <a
                    :href="discogsUrl"
                    target="_blank"
                    rel="noreferrer noopener"
                    class="basic item"
                  >
                    <i class="external icon" />
                    <translate translate-context="Content/*/Button.Label/Verb">Search on Discogs</translate>
                  </a>
                  <router-link
                    v-if="object.is_local"
                    :to="{name: 'library.artists.edit', params: {id: object.id }}"
                    class="basic item"
                  >
                    <i class="edit icon" />
                    <translate translate-context="Content/*/Button.Label/Verb">
                      Edit
                    </translate>
                  </router-link>
                  <div class="divider" />
                  <div
                    v-for="obj in getReportableObjs({artist: object})"
                    :key="obj.target.type + obj.target.id"
                    role="button"
                    class="basic item"
                    @click.stop.prevent="$store.dispatch('moderation/report', obj.target)"
                  >
                    <i class="share icon" /> {{ obj.label }}
                  </div>

                  <div class="divider" />
                  <router-link
                    v-if="$store.state.auth.availablePermissions['library']"
                    class="basic item"
                    :to="{name: 'manage.library.artists.detail', params: {id: object.id}}"
                  >
                    <i class="wrench icon" />
                    <translate translate-context="Content/Moderation/Link">
                      Open in moderation interface
                    </translate>
                  </router-link>
                  <a
                    v-if="$store.state.auth.profile && $store.state.auth.profile.is_superuser"
                    class="basic item"
                    :href="$store.getters['instance/absoluteUrl'](`/api/admin/music/artist/${object.id}`)"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    <i class="wrench icon" />
                    <translate translate-context="Content/Moderation/Link/Verb">View in Django's admin</translate>&nbsp;
                  </a>
                </div>
              </button>
            </div>
          </div>
        </div>
      </section>
      <router-view
        :key="$route.fullPath"
        :tracks="tracks"
        :next-tracks-url="nextTracksUrl"
        :next-albums-url="nextAlbumsUrl"
        :albums="albums"
        :is-loading-albums="isLoadingAlbums"
        :object="object"
        object-type="artist"
        @libraries-loaded="libraries = $event"
      />
    </template>
  </main>
</template>

<script>
import axios from 'axios'
import PlayButton from '~/components/audio/PlayButton.vue'
import EmbedWizard from '~/components/audio/EmbedWizard.vue'
import Modal from '~/components/semantic/Modal.vue'
import RadioButton from '~/components/radios/Button.vue'
import TagsList from '~/components/tags/List.vue'
import ReportMixin from '~/components/mixins/Report.vue'

import { getDomain } from '~/utils'
import useLogger from '~/composables/useLogger'

const logger = useLogger()

export default {
  components: {
    PlayButton,
    EmbedWizard,
    Modal,
    RadioButton,
    TagsList
  },
  mixins: [ReportMixin],
  props: { id: { type: [String, Number], required: true } },
  data () {
    return {
      isLoading: true,
      isLoadingAlbums: true,
      object: null,
      albums: null,
      libraries: [],
      showEmbedModal: false,
      tracks: [],
      nextAlbumsUrl: null,
      nextTracksUrl: null,
      totalAlbums: null,
      totalTracks: null
    }
  },
  computed: {
    domain () {
      if (this.object) {
        return getDomain(this.object.fid)
      }
      return null
    },
    isPlayable () {
      return (
        this.object.albums.filter(a => {
          return a.is_playable
        }).length > 0
      )
    },
    labels () {
      return {
        title: this.$pgettext('*/*/*', 'Album')
      }
    },
    wikipediaUrl () {
      return (
        'https://en.wikipedia.org/w/index.php?search=' +
        encodeURI(this.object.name)
      )
    },
    musicbrainzUrl () {
      if (this.object.mbid) {
        return 'https://musicbrainz.org/artist/' + this.object.mbid
      }
      return null
    },
    discogsUrl () {
      return (
        'https://discogs.com/search/?type=artist&title=' +
        encodeURI(this.object.name)
      )
    },
    cover () {
      if (this.object.cover && this.object.cover.urls.original) {
        return this.object.cover
      }
      return this.object.albums
        .filter(album => {
          return album.cover && album.cover.urls.original
        })
        .map(album => {
          return album.cover
        })[0]
    },

    publicLibraries () {
      return this.libraries.filter(l => {
        return l.privacy_level === 'everyone'
      })
    },
    headerStyle () {
      if (!this.cover || !this.cover.urls.original) {
        return ''
      }
      return (
        'background-image: url(' +
        this.$store.getters['instance/absoluteUrl'](this.cover.urls.original) +
        ')'
      )
    },
    contentFilter () {
      return this.$store.getters['moderation/artistFilters']().filter((e) => {
        return e.target.id === this.object.id
      })[0]
    }
  },
  watch: {
    id () {
      this.fetchData()
    }
  },
  async created () {
    await this.fetchData()
  },
  methods: {
    async fetchData () {
      const self = this
      this.isLoading = true
      logger.debug('Fetching artist "' + this.id + '"')

      const artistPromise = axios.get('artists/' + this.id + '/', { params: { refresh: 'true' } }).then(response => {
        if (response.data.channel) {
          self.$router.replace({ name: 'channels.detail', params: { id: response.data.channel.uuid } })
        } else {
          self.object = response.data
        }
      })
      await artistPromise
      if (!self.object) {
        return
      }
      const trackPromise = axios.get('tracks/', { params: { artist: this.id, hidden: '', ordering: '-creation_date' } }).then(response => {
        self.tracks = response.data.results
        self.nextTracksUrl = response.data.next
        self.totalTracks = response.data.count
      })
      const albumPromise = axios.get('albums/', {
        params: { artist: self.id, ordering: '-release_date', hidden: '' }
      }).then(response => {
        self.nextAlbumsUrl = response.data.next
        self.totalAlbums = response.data.count
        const parsed = JSON.parse(JSON.stringify(response.data.results))
        self.albums = parsed
      })
      await trackPromise
      await albumPromise
      self.isLoadingAlbums = false
      self.isLoading = false
    }
  }
}
</script>
