<template>
  <main>
    <div
      v-if="isLoading"
      v-title="labels.title"
      class="ui vertical segment"
    >
      <div :class="['ui', 'centered', 'active', 'inline', 'loader']" />
    </div>
    <template v-if="object">
      <section class="ui vertical stripe segment channel-serie">
        <div class="ui stackable grid container">
          <div class="ui seven wide column">
            <div
              v-if="isSerie"
              class="padded basic segment"
            >
              <div
                v-if="isSerie"
                class="ui two column grid"
              >
                <div class="column">
                  <div class="large two-images">
                    <img
                      v-if="object.cover && object.cover.urls.original"
                      v-lazy="$store.getters['instance/absoluteUrl'](object.cover.urls.medium_square_crop)"
                      alt=""
                      class="channel-image"
                    >
                    <img
                      v-else
                      alt=""
                      class="channel-image"
                      src="../../assets/audio/default-cover.png"
                    >
                    <img
                      v-if="object.cover && object.cover.urls.original"
                      v-lazy="$store.getters['instance/absoluteUrl'](object.cover.urls.medium_square_crop)"
                      alt=""
                      class="channel-image"
                    >
                    <img
                      v-else
                      alt=""
                      class="channel-image"
                      src="../../assets/audio/default-cover.png"
                    >
                  </div>
                </div>
                <div class="ui column right aligned">
                  <tags-list
                    v-if="object.tags && object.tags.length > 0"
                    :tags="object.tags"
                  />
                  <div class="ui small hidden divider" />
                  <human-duration
                    v-if="totalDuration > 0"
                    :duration="totalDuration"
                  />
                  <template v-if="totalTracks > 0">
                    <div class="ui hidden very small divider" />
                    <translate
                      v-if="isSerie"
                      translate-context="Content/Channel/Paragraph"
                      translate-plural="%{ count } episodes"
                      :translate-n="totalTracks"
                      :translate-params="{count: totalTracks}"
                    >
                      %{ count } episode
                    </translate>
                    <translate
                      v-else
                      translate-context="*/*/*"
                      :translate-params="{count: totalTracks}"
                      :translate-n="totalTracks"
                      translate-plural="%{ count } tracks"
                    >
                      %{ count } track
                    </translate>
                  </template>
                  <div class="ui small hidden divider" />
                  <play-button
                    class="vibrant"
                    :tracks="object.tracks"
                    :is-playable="object.is_playable"
                  />
                  <div class="ui hidden horizontal divider" />
                  <album-dropdown
                    :object="object"
                    :public-libraries="publicLibraries"
                    :is-loading="isLoading"
                    :is-album="isAlbum"
                    :is-serie="isSerie"
                    :is-channel="isChannel"
                    :artist="artist"
                  />
                </div>
              </div>
              <div class="ui small hidden divider" />
              <header>
                <h2
                  class="ui header"
                  :title="object.title"
                >
                  {{ object.title }}
                </h2>
                <artist-label :artist="artist" />
              </header>
            </div>
            <div
              v-else
              class="ui center aligned text padded basic segment"
            >
              <img
                v-if="object.cover && object.cover.urls.original"
                v-lazy="$store.getters['instance/absoluteUrl'](object.cover.urls.medium_square_crop)"
                alt=""
                class="channel-image"
              >
              <img
                v-else
                alt=""
                class="channel-image"
                src="../../assets/audio/default-cover.png"
              >
              <div class="ui hidden divider" />
              <header>
                <h2
                  class="ui header"
                  :title="object.title"
                >
                  {{ object.title }}
                </h2>
                <artist-label
                  class="rounded"
                  :artist="artist"
                />
              </header>
              <div
                v-if="object.release_date || (totalTracks > 0)"
                class="ui small hidden divider"
              />
              <span v-if="object.release_date">{{ momentFormat(object.release_date, 'Y') }} · </span>
              <template v-if="totalTracks > 0">
                <translate
                  v-if="isSerie"
                  translate-context="Content/Channel/Paragraph"
                  translate-plural="%{ count } episodes"
                  :translate-n="totalTracks"
                  :translate-params="{count: totalTracks}"
                >
                  %{ count } episode
                </translate>
                <translate
                  v-else
                  translate-context="*/*/*"
                  :translate-params="{count: totalTracks}"
                  :translate-n="totalTracks"
                  translate-plural="%{ count } tracks"
                >
                  %{ count } track
                </translate> ·
              </template>
              <human-duration
                v-if="totalDuration > 0"
                :duration="totalDuration"
              />
              <div class="ui small hidden divider" />
              <play-button
                class="vibrant"
                :album="object"
                :is-playable="object.is_playable"
              />
              <div class="ui horizontal hidden divider" />
              <album-dropdown
                :object="object"
                :public-libraries="publicLibraries"
                :is-loading="isLoading"
                :is-album="isAlbum"
                :is-serie="isSerie"
                :is-channel="isChannel"
                :artist="artist"
              />
              <div v-if="(object.tags && object.tags.length > 0) || object.description || $store.state.auth.authenticated && object.is_local">
                <div class="ui small hidden divider" />
                <div class="ui divider" />
                <div class="ui small hidden divider" />
                <template v-if="object.tags && object.tags.length > 0">
                  <tags-list :tags="object.tags" />
                  <div class="ui small hidden divider" />
                </template>
                <rendered-description
                  v-if="object.description"
                  :content="object.description"
                  :can-update="false"
                />
                <router-link
                  v-else-if="$store.state.auth.authenticated && object.is_local"
                  :to="{name: 'library.albums.edit', params: {id: object.id }}"
                >
                  <i class="pencil icon" />
                  <translate translate-context="Content/*/Button.Label/Verb">
                    Add a description…
                  </translate>
                </router-link>
              </div>
            </div>
            <template v-if="isSerie">
              <div class="ui hidden divider" />
              <rendered-description
                v-if="object.description"
                :content="object.description"
                :can-update="false"
              />
              <router-link
                v-else-if="$store.state.auth.authenticated && object.is_local"
                :to="{name: 'library.albums.edit', params: {id: object.id }}"
              >
                <i class="pencil icon" />
                <translate translate-context="Content/*/Button.Label/Verb">
                  Add a description…
                </translate>
              </router-link>
            </template>
          </div>
          <div class="nine wide column">
            <router-view
              v-if="object"
              :key="$route.fullPath"
              :paginate-by="paginateBy"
              :page="page"
              :total-tracks="totalTracks"
              :is-serie="isSerie"
              :artist="artist"
              :discs="discs"
              :object="object"
              object-type="album"
              @libraries-loaded="libraries = $event"
              @page-changed="page = $event"
            />
          </div>
        </div>
      </section>
    </template>
  </main>
</template>

<script>
import axios from 'axios'
import { sum } from 'lodash-es'
import PlayButton from '~/components/audio/PlayButton.vue'
import TagsList from '~/components/tags/List.vue'
import ArtistLabel from '~/components/audio/ArtistLabel.vue'
import AlbumDropdown from './AlbumDropdown.vue'
import { momentFormat } from '~/utils/filters'

function groupByDisc (initial) {
  function inner (acc, track) {
    const dn = track.disc_number - initial
    if (acc[dn] === undefined) {
      acc.push([track])
    } else {
      acc[dn].push(track)
    }
    return acc
  }
  return inner
}

export default {
  components: {
    PlayButton,
    TagsList,
    ArtistLabel,
    AlbumDropdown
  },
  props: { id: { type: [String, Number], required: true } },
  setup () {
    return { momentFormat }
  },
  data () {
    return {
      isLoading: true,
      object: null,
      artist: null,
      discs: [],
      libraries: [],
      page: 1,
      paginateBy: 50
    }
  },
  computed: {
    totalTracks () {
      return this.object.tracks_count
    },
    isChannel () {
      return !!this.object.artist.channel
    },
    isSerie () {
      return this.object.artist.content_category === 'podcast'
    },
    isAlbum () {
      return this.object.artist.content_category === 'music'
    },
    totalDuration () {
      const durations = [0]
      this.object.tracks.forEach((t) => {
        if (t.uploads[0] && t.uploads[0].duration) {
          durations.push(t.uploads[0].duration)
        }
      })
      return sum(durations)
    },
    labels () {
      return {
        title: this.$pgettext('*/*/*', 'Album')
      }
    },
    publicLibraries () {
      return this.libraries.filter(l => {
        return l.privacy_level === 'everyone'
      })
    }
  },
  watch: {
    id () {
      this.fetchData()
    },
    page () {
      this.fetchData()
    }
  },
  async created () {
    await this.fetchData()
  },
  methods: {
    async fetchData () {
      this.isLoading = true
      let tracksResponse = axios.get('tracks/', { params: { ordering: 'disc_number,position', album: this.id, page_size: this.paginateBy, page: this.page, include_channels: 'true' } })
      const albumResponse = await axios.get(`albums/${this.id}/`, { params: { refresh: 'true' } })
      const artistResponse = await axios.get(`artists/${albumResponse.data.artist.id}/`)
      this.artist = artistResponse.data
      if (this.artist.channel) {
        this.artist.channel.artist = this.artist
      }
      tracksResponse = await tracksResponse
      this.object = albumResponse.data
      this.object.tracks = tracksResponse.data.results
      this.discs = this.object.tracks.reduce(groupByDisc(this.object.tracks[0].disc_number), [])
      this.isLoading = false
    },
    remove () {
      const self = this
      self.isLoading = true
      axios.delete(`albums/${this.object.id}`).then((response) => {
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
