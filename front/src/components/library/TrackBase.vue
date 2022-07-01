<template>
  <main>
    <div
      v-if="isLoading"
      v-title="labels.title"
      class="ui vertical segment"
    >
      <div :class="['ui', 'centered', 'active', 'inline', 'loader']" />
    </div>
    <template v-if="track">
      <section
        v-title="track.title"
        :class="['ui', 'head', 'vertical', 'center', 'aligned', 'stripe', 'segment']"
      >
        <div class="ui basic padded segment">
          <div class="ui stackable grid row container">
            <div class="eight wide left aligned column">
              <h1 class="ui header">
                {{ track.title }}
                <sanitized-html
                  class="sub header"
                  :html="subtitle"
                />
              </h1>
            </div>
            <div class="eight wide right aligned column button-group">
              <play-button
                class="vibrant"
                :track="track"
              >
                <translate translate-context="*/Queue/Button.Label/Short, Verb">
                  Play
                </translate>
              </play-button>
              &nbsp;
              <track-favorite-icon
                v-if="$store.state.auth.authenticated"
                :border="true"
                :track="track"
              />
              <track-playlist-icon
                v-if="$store.state.auth.authenticated"
                class="circular"
                :border="true"
                :track="track"
              />
              <a
                v-if="upload"
                role="button"
                :aria-label="labels.download"
                :href="downloadUrl"
                target="_blank"
                class="ui basic circular icon button"
                :title="labels.download"
              >
                <i class="download icon" />
              </a>
              <modal
                v-if="isEmbedable"
                v-model:show="showEmbedModal"
              >
                <h4 class="header">
                  <translate translate-context="Popup/Track/Title">
                    Embed this track on your website
                  </translate>
                </h4>
                <div class="scrolling content">
                  <div class="description">
                    <embed-wizard
                      :id="track.id"
                      type="track"
                    />
                  </div>
                </div>
                <div class="actions">
                  <button class="ui basic deny button">
                    <translate translate-context="*/*/Button.Label/Verb">
                      Cancel
                    </translate>
                  </button>
                </div>
              </modal>
              <button
                v-dropdown="{direction: 'downward'}"
                class="ui floating dropdown circular icon basic button"
                :title="labels.more"
              >
                <i class="ellipsis vertical icon" />
                <div
                  class="menu"
                  style="right: 0; left: auto"
                >
                  <a
                    v-if="domain != $store.getters['instance/domain']"
                    :href="track.fid"
                    target="_blank"
                    class="basic item"
                  >
                    <i class="external icon" />
                    <translate
                      :translate-params="{domain: domain}"
                      translate-context="Content/*/Button.Label/Verb"
                    >View on %{ domain }</translate>
                  </a>
                  <div
                    v-if="isEmbedable"
                    role="button"
                    class="basic item"
                    @click="showEmbedModal = !showEmbedModal"
                  >
                    <i class="code icon" />
                    <translate translate-context="Content/*/Button.Label/Verb">
                      Embed
                    </translate>
                  </div>
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
                    v-if="discogsUrl"
                    :href="discogsUrl"
                    target="_blank"
                    rel="noreferrer noopener"
                    class="basic item"
                  >
                    <i class="external icon" />
                    <translate translate-context="Content/*/Button.Label/Verb">Search on Discogs</translate>
                  </a>
                  <router-link
                    v-if="track.is_local"
                    :to="{name: 'library.tracks.edit', params: {id: track.id }}"
                    class="basic item"
                  >
                    <i class="edit icon" />
                    <translate translate-context="Content/*/Button.Label/Verb">
                      Edit
                    </translate>
                  </router-link>
                  <dangerous-button
                    v-if="artist && $store.state.auth.authenticated && artist.channel && artist.attributed_to.full_username === $store.state.auth.fullUsername"
                    :class="['ui', {loading: isLoading}, 'item']"
                    @confirm="remove()"
                  >
                    <i class="ui trash icon" />
                    <translate translate-context="*/*/*/Verb">
                      Delete…
                    </translate>
                    <template #modal-header>
                      <p>
                        <translate translate-context="Popup/Channel/Title">
                          Delete this track?
                        </translate>
                      </p>
                    </template>
                    <template #modal-content>
                      <div>
                        <p>
                          <translate translate-context="Content/Moderation/Paragraph">
                            The track will be deleted, as well as any related files and data. This action is irreversible.
                          </translate>
                        </p>
                      </div>
                    </template>
                    <template #modal-confirm>
                      <p>
                        <translate translate-context="*/*/*/Verb">
                          Delete
                        </translate>
                      </p>
                    </template>
                  </dangerous-button>
                  <div class="divider" />
                  <div
                    v-for="obj in getReportableObjs({track})"
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
                    :to="{name: 'manage.library.tracks.detail', params: {id: track.id}}"
                  >
                    <i class="wrench icon" />
                    <translate translate-context="Content/Moderation/Link">
                      Open in moderation interface
                    </translate>
                  </router-link>
                  <a
                    v-if="$store.state.auth.profile && $store.state.auth.profile.is_superuser"
                    class="basic item"
                    :href="$store.getters['instance/absoluteUrl'](`/api/admin/music/track/${track.id}`)"
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
        v-if="track"
        :key="$route.fullPath"
        :track="track"
        :object="track"
        object-type="track"
        @libraries-loaded="libraries = $event"
      />
    </template>
  </main>
</template>

<script>
import time from '~/utils/time'
import axios from 'axios'
import { getDomain } from '~/utils'
import PlayButton from '~/components/audio/PlayButton.vue'
import TrackFavoriteIcon from '~/components/favorites/TrackFavoriteIcon.vue'
import TrackPlaylistIcon from '~/components/playlists/TrackPlaylistIcon.vue'
import Modal from '~/components/semantic/Modal.vue'
import EmbedWizard from '~/components/audio/EmbedWizard.vue'
import ReportMixin from '~/components/mixins/Report.vue'
import { momentFormat } from '~/utils/filters'
import updateQueryString from '~/composables/updateQueryString'
import useLogger from '~/composables/useLogger'

const logger = useLogger()

const FETCH_URL = 'tracks/'

function escapeHtml (unsafe) {
  return unsafe
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;')
}

export default {
  components: {
    PlayButton,
    TrackPlaylistIcon,
    TrackFavoriteIcon,
    Modal,
    EmbedWizard
  },
  mixins: [ReportMixin],
  props: { id: { type: [String, Number], required: true } },
  data () {
    return {
      time,
      isLoading: true,
      track: null,
      artist: null,
      showEmbedModal: false,
      libraries: []
    }
  },
  computed: {
    domain () {
      if (this.track) {
        return getDomain(this.track.fid)
      }
      return null
    },
    publicLibraries () {
      return this.libraries.filter(l => {
        return l.privacy_level === 'everyone'
      })
    },
    isEmbedable () {
      const self = this
      return (self.artist && self.artist.channel && self.artist.channel.actor) || this.publicLibraries.length > 0
    },
    upload () {
      if (this.track.uploads) {
        return this.track.uploads[0]
      }
      return null
    },
    labels () {
      return {
        title: this.$pgettext('*/*/*/Noun', 'Track'),
        download: this.$pgettext('Content/Track/Link/Verb', 'Download'),
        more: this.$pgettext('*/*/Button.Label/Noun', 'More…')
      }
    },
    wikipediaUrl () {
      return (
        'https://en.wikipedia.org/w/index.php?search=' +
        encodeURI(this.track.title + ' ' + this.track.artist.name)
      )
    },
    discogsUrl () {
      if (this.track.album) {
        return (
          'https://discogs.com/search/?type=release&title=' +
    encodeURI(this.track.album.title) + '&artist=' +
    encodeURI(this.track.artist.name) + '&track=' +
    encodeURI(this.track.title)
        )
      }
      return null
    },
    downloadUrl () {
      const url = this.$store.getters['instance/absoluteUrl'](
        this.upload.listen_url
      )

      if (this.$store.state.auth.authenticated) {
        return updateQueryString(
          url,
          'token',
          encodeURI(this.$store.state.auth.scopedTokens.listen)
        )
      }

      return url
    },
    attributedToUrl () {
      const route = this.$router.resolve({
        name: 'profile.full.overview',
        params: {
          username: this.track.attributed_to.preferred_username,
          domain: this.track.attributed_to.domain
        }
      })
      return route.href
    },
    albumUrl () {
      const route = this.$router.resolve({ name: 'library.albums.detail', params: { id: this.track.album.id } })
      return route.href
    },
    artistUrl () {
      const route = this.$router.resolve({ name: 'library.artists.detail', params: { id: this.track.artist.id } })
      return route.href
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
    subtitle () {
      let msg
      if (this.track.attributed_to) {
        msg = this.$pgettext('Content/Track/Paragraph', 'Uploaded by <a class="internal" href="%{ uploaderUrl }">%{ uploader }</a> on <time title="%{ date }" datetime="%{ date }">%{ prettyDate }</time>')
        return this.$gettextInterpolate(msg, {
          uploaderUrl: this.attributedToUrl,
          uploader: escapeHtml(`@${this.track.attributed_to.full_username}`),
          date: escapeHtml(this.track.creation_date),
          prettyDate: escapeHtml(momentFormat(this.track.creation_date, 'LL'))
        })
      } else {
        msg = this.$pgettext('Content/Track/Paragraph', 'Uploaded on <time title="%{ date }" datetime="%{ date }">%{ prettyDate }</time>')
        return this.$gettextInterpolate(msg, {
          date: escapeHtml(this.track.creation_date),
          prettyDate: escapeHtml(momentFormat(this.track.creation_date, 'LL'))
        })
      }
    }
  },
  watch: {
    id () {
      this.fetchData()
    }
  },
  created () {
    this.fetchData()
  },
  methods: {
    fetchData () {
      const self = this
      this.isLoading = true
      const url = FETCH_URL + this.id + '/'
      logger.debug('Fetching track "' + this.id + '"')
      axios.get(url, { params: { refresh: 'true' } }).then(response => {
        self.track = response.data
        axios.get(`artists/${response.data.artist.id}/`).then(response => {
          self.artist = response.data
        })
        self.isLoading = false
      })
    },
    remove () {
      const self = this
      self.isLoading = true
      axios.delete(`tracks/${this.track.id}`).then((response) => {
        self.isLoading = false
        self.$emit('deleted')
        self.$router.push({ name: 'library.artists.detail', params: { id: this.artist.id } })
      }, error => {
        self.isLoading = false
        self.errors = error.backendErrors
      })
    }
  }
}
</script>
