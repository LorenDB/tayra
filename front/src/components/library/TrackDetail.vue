<template>
  <div v-if="track">
    <section class="ui vertical stripe segment">
      <div class="ui stackable grid row container">
        <div class="six wide column">
          <template v-if="upload">
            <img
              v-if="track.cover && track.cover.urls.large_square_crop"
              v-lazy="$store.getters['instance/absoluteUrl'](track.cover.urls.large_square_crop)"
              alt="Cover Image"
              class="ui fluid image track-cover-image"
            >
            <img
              v-else-if="track.album && track.album.cover && track.album.cover.urls.large_square_crop"
              v-lazy="$store.getters['instance/absoluteUrl'](track.album.cover.urls.large_square_crop)"
              alt="Cover Image"
              class="ui fluid image track-cover-image"
            >
            <img
              v-else
              src="../../assets/audio/default-cover.png"
              alt="Cover Image"
              class="ui fluid image track-cover-image"
            >
            <h3 class="ui header">
              <translate
                v-if="track.artist.content_category === 'music'"
                key="1"
                translate-context="Content/*/*"
              >
                Track Details
              </translate>
              <translate
                v-else
                key="2"
                translate-context="Content/*/*"
              >
                Episode Details
              </translate>
            </h3>
            <table class="ui basic table">
              <tbody>
                <tr>
                  <td>
                    <translate translate-context="Content/*/*">
                      Duration
                    </translate>
                  </td>
                  <td class="right aligned">
                    <template v-if="upload.duration">
                      {{ upload.duration | duration }}
                    </template>
                    <translate
                      v-else
                      translate-context="*/*/*"
                    >
                      N/A
                    </translate>
                  </td>
                </tr>
                <tr>
                  <td>
                    <translate translate-context="Content/*/*/Noun">
                      Size
                    </translate>
                  </td>
                  <td class="right aligned">
                    <template v-if="upload.size">
                      {{ upload.size | humanSize }}
                    </template>
                    <translate
                      v-else
                      translate-context="*/*/*"
                    >
                      N/A
                    </translate>
                  </td>
                </tr>
                <tr>
                  <td>
                    <translate translate-context="Content/*/*/Noun">
                      Codec
                    </translate>
                  </td>
                  <td class="right aligned">
                    <template v-if="upload.extension">
                      {{ upload.extension }}
                    </template>
                    <translate
                      v-else
                      translate-context="*/*/*"
                    >
                      N/A
                    </translate>
                  </td>
                </tr>
                <tr>
                  <td>
                    <translate translate-context="Content/Track/*/Noun">
                      Bitrate
                    </translate>
                  </td>
                  <td class="right aligned">
                    <template v-if="upload.bitrate">
                      {{ upload.bitrate | humanSize }}/s
                    </template>
                    <translate
                      v-else
                      translate-context="*/*/*"
                    >
                      N/A
                    </translate>
                  </td>
                </tr>
                <tr>
                  <td>
                    <translate translate-context="Content/*/*">
                      Downloads
                    </translate>
                  </td>
                  <td class="right aligned">
                    {{ track.downloads_count }}
                  </td>
                </tr>
              </tbody>
            </table>
          </template>
        </div>
        <div class="ten wide column">
          <template v-if="track.tags && track.tags.length > 0">
            <tags-list :tags="track.tags" />
            <div class="ui hidden divider" />
          </template>

          <rendered-description
            :content="track.description"
            :can-update="false"
          />
          <h2 class="ui header">
            <translate translate-context="Content/*/*">
              Release Details
            </translate>
          </h2>
          <table class="ui basic table ellipsis-rows">
            <tbody>
              <tr>
                <td>
                  <translate translate-context="*/*/*/Noun">
                    Artist
                  </translate>
                </td>
                <td class="right aligned">
                  <router-link :to="{name: 'library.artists.detail', params: {id: track.artist.id}}">
                    {{ track.artist.name }}
                  </router-link>
                </td>
              </tr>
              <tr v-if="track.album">
                <td>
                  <translate
                    v-if="track.album.artist.content_category === 'music'"
                    key="1"
                    translate-context="*/*/*/Noun"
                  >
                    Album
                  </translate>
                  <translate
                    v-else
                    key="2"
                    translate-context="*/*/*"
                  >
                    Serie
                  </translate>
                </td>
                <td class="right aligned">
                  <router-link :to="{name: 'library.albums.detail', params: {id: track.album.id}}">
                    {{ track.album.title }}
                  </router-link>
                </td>
              </tr>
              <tr>
                <td>
                  <translate translate-context="*/*/*">
                    Year
                  </translate>
                </td>
                <td class="right aligned">
                  <template v-if="track.album && track.album.release_date">
                    {{ track.album.release_date | moment('Y') }}
                  </template>
                  <template v-else>
                    <translate translate-context="*/*/*">
                      N/A
                    </translate>
                  </template>
                </td>
              </tr>
              <tr>
                <td>
                  <translate translate-context="Content/Track/*/Noun">
                    Copyright
                  </translate>
                </td>
                <td class="right aligned">
                  <span
                    v-if="track.copyright"
                    :title="track.copyright"
                  >{{ track.copyright|truncate(50) }}</span>
                  <template v-else>
                    <translate translate-context="*/*/*">
                      N/A
                    </translate>
                  </template>
                </td>
              </tr>
              <tr>
                <td>
                  <translate translate-context="Content/*/*/Noun">
                    License
                  </translate>
                </td>
                <td class="right aligned">
                  <a
                    v-if="license"
                    :href="license.url"
                    target="_blank"
                    rel="noopener noreferrer"
                  >{{ license.name }}</a>
                  <translate
                    v-else
                    translate-context="*/*/*"
                  >
                    N/A
                  </translate>
                </td>
              </tr>
              <tr v-if="!track.is_local">
                <td>
                  <translate translate-context="Content/*/*/Noun">
                    URL
                  </translate>
                </td>
                <td :title="track.fid">
                  <a
                    :href="track.fid"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    {{ track.fid|truncate(65) }}
                  </a>
                </td>
              </tr>
            </tbody>
          </table>
          <a
            v-if="musicbrainzUrl"
            :href="musicbrainzUrl"
            target="_blank"
            rel="noreferrer noopener"
          >
            <i class="external icon" />
            <translate translate-context="Content/*/*/Clickable, Verb">View on MusicBrainz</translate>
          </a>
          <h2 class="ui header">
            <translate translate-context="Content/*/Title/Noun">
              Related Playlists
            </translate>
          </h2>
          <playlist-widget
            :url="'playlists/'"
            :filters="{track: track.id, playable: true, ordering: '-modification_date'}"
          />

          <h2 class="ui header">
            <translate translate-context="Content/*/Title/Noun">
              Related Libraries
            </translate>
          </h2>
          <library-widget
            :url="'tracks/' + id + '/libraries/'"
            @loaded="$emit('libraries-loaded', $event)"
          >
            <translate
              slot="subtitle"
              translate-context="Content/Track/Paragraph"
            >
              This track is present in the following libraries:
            </translate>
          </library-widget>
        </div>
      </div>
    </section>
  </div>
</template>

<script>
import axios from 'axios'
import LibraryWidget from '~/components/federation/LibraryWidget.vue'
import TagsList from '~/components/tags/List.vue'
import PlaylistWidget from '~/components/playlists/Widget.vue'

export default {
  components: {
    LibraryWidget,
    TagsList,
    PlaylistWidget
  },
  props: {
    track: { type: Object, required: true },
    libraries: { type: Array, default: null }
  },
  data () {
    return {
      id: this.track.id,
      licenseData: null
    }
  },
  computed: {
    labels () {
      return {
        title: this.$pgettext('*/*/*/Noun', 'Track')
      }
    },
    musicbrainzUrl () {
      if (this.track.mbid) {
        return 'https://musicbrainz.org/recording/' + this.track.mbid
      }
      return null
    },
    upload () {
      if (this.track.uploads) {
        return this.track.uploads[0]
      }
      return null
    },
    license () {
      if (!this.track || !this.track.license) {
        return null
      }
      return this.licenseData
    },
    cover () {
      if (this.track.cover && this.track.cover.urls.original) {
        return this.track.cover
      }
      if (this.track.album && this.track.album.cover) {
        return this.track.album.cover
      }
      return null
    }
  },
  watch: {
    track (v) {
      if (v && v.license) {
        this.fetchLicenseData(v.license)
      }
    }
  },
  created () {
    if (this.track && this.track.license) {
      this.fetchLicenseData(this.track.license)
    }
  },
  methods: {
    fetchLicenseData (licenseId) {
      const self = this
      const url = `licenses/${licenseId}`
      axios.get(url).then(response => {
        self.licenseData = response.data
      })
    }
  }
}
</script>
