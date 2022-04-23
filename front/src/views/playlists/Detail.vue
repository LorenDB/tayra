<template>
  <main>
    <div
      v-if="isLoading"
      v-title="labels.playlist"
      class="ui vertical segment"
    >
      <div :class="['ui', 'centered', 'active', 'inline', 'loader']" />
    </div>
    <section
      v-if="!isLoading && playlist"
      v-title="playlist.name"
      class="ui head vertical center aligned stripe segment"
    >
      <div class="segment-content">
        <h2 class="ui center aligned icon header">
          <i class="circular inverted list warning icon" />
          <div class="content">
            {{ playlist.name }}
            <div class="sub header">
              <translate
                translate-plural="Playlist containing %{ count } tracks, by %{ username }"
                :translate-n="playlist.tracks_count"
                :translate-params="{count: playlist.tracks_count, username: playlist.user.username}"
                translate-context="Content/Playlist/Header.Subtitle"
              >
                Playlist containing %{ count } track, by %{ username }
              </translate><br>
              <duration :seconds="playlist.duration" />
            </div>
          </div>
        </h2>
        <div class="ui hidden divider" />
        <div class="header-buttons">
          <div class="ui buttons">
            <play-button
              class="vibrant"
              :is-playable="playlist.is_playable"
              :tracks="tracks"
            >
              <translate translate-context="Content/Queue/Button.Label/Short, Verb">
                Play all
              </translate>
            </play-button>
          </div>
          <div class="ui buttons">
            <button
              v-if="$store.state.auth.profile && playlist.user.id === $store.state.auth.profile.id"
              class="ui icon labeled button"
              @click="edit = !edit"
            >
              <i class="pencil icon" />
              <template v-if="edit">
                <translate translate-context="Content/Playlist/Button.Label/Verb">
                  Stop Editing
                </translate>
              </template>
              <template v-else>
                <translate translate-context="Content/*/Button.Label/Verb">
                  Edit
                </translate>
              </template>
            </button>
          </div>
          <div class="ui buttons">
            <button
              v-if="playlist.privacy_level === 'everyone' && playlist.is_playable"
              class="ui icon labeled button"
              @click="showEmbedModal = !showEmbedModal"
            >
              <i class="code icon" />
              <translate translate-context="Content/*/Button.Label/Verb">
                Embed
              </translate>
            </button>
            <dangerous-button
              v-if="$store.state.auth.profile && playlist.user.id === $store.state.auth.profile.id"
              class="ui labeled danger icon button"
              :action="deletePlaylist"
            >
              <i class="trash icon" /> <translate translate-context="*/*/*/Verb">
                Delete
              </translate>
              <p
                slot="modal-header"
                v-translate="{playlist: playlist.name}"
                translate-context="Popup/Playlist/Title/Call to action"
                :translate-params="{playlist: playlist.name}"
              >
                Do you want to delete the playlist "%{ playlist }"?
              </p>
              <p slot="modal-content">
                <translate translate-context="Popup/Playlist/Paragraph">
                  This will completely delete this playlist and cannot be undone.
                </translate>
              </p>
              <div slot="modal-confirm">
                <translate translate-context="Popup/Playlist/Button.Label/Verb">
                  Delete playlist
                </translate>
              </div>
            </dangerous-button>
          </div>
        </div>
        <modal
          v-if="playlist.privacy_level === 'everyone' && playlist.is_playable"
          :show.sync="showEmbedModal"
        >
          <h4 class="header">
            <translate translate-context="Popup/Album/Title/Verb">
              Embed this playlist on your website
            </translate>
          </h4>
          <div class="scrolling content">
            <div class="description">
              <embed-wizard
                :id="playlist.id"
                type="playlist"
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
      </div>
    </section>
    <section class="ui vertical stripe segment">
      <template v-if="edit">
        <playlist-editor
          :playlist="playlist"
          :playlist-tracks="playlistTracks"
          @playlist-updated="playlist = $event"
          @tracks-updated="updatePlts"
        />
      </template>
      <template v-else-if="tracks.length > 0">
        <h2>
          <translate translate-context="*/*/*">
            Tracks
          </translate>
        </h2>
        <track-table
          :display-position="true"
          :tracks="tracks"
        />
      </template>
      <div
        v-else
        class="ui placeholder segment"
      >
        <div class="ui icon header">
          <i class="list icon" />
          <translate translate-context="Content/Home/Placeholder">
            There are no tracks in this playlist yet
          </translate>
        </div>
        <button
          class="ui success icon labeled button"
          @click="edit = !edit"
        >
          <i class="pencil icon" />
          <translate translate-context="Content/Home/CreatePlaylist">
            Edit
          </translate>
        </button>
      </div>
    </section>
  </main>
</template>
<script>
import axios from 'axios'
import TrackTable from '~/components/audio/track/Table.vue'
import PlayButton from '~/components/audio/PlayButton.vue'
import PlaylistEditor from '~/components/playlists/Editor.vue'
import EmbedWizard from '~/components/audio/EmbedWizard.vue'
import Modal from '~/components/semantic/Modal.vue'

export default {
  components: {
    PlaylistEditor,
    TrackTable,
    PlayButton,
    Modal,
    EmbedWizard
  },
  props: {
    id: { type: [Number, String], required: true },
    defaultEdit: { type: Boolean, default: false }
  },
  data: function () {
    return {
      edit: this.defaultEdit,
      isLoading: false,
      playlist: null,
      tracks: [],
      playlistTracks: [],
      showEmbedModal: false
    }
  },
  computed: {
    labels () {
      return {
        playlist: this.$pgettext('*/*/*', 'Playlist')
      }
    }
  },
  created: function () {
    this.fetch()
  },
  methods: {
    updatePlts (v) {
      this.playlistTracks = v
      this.tracks = v.map((e, i) => {
        const track = e.track
        track.position = i + 1
        return track
      })
    },
    fetch: function () {
      const self = this
      self.isLoading = true
      const url = 'playlists/' + this.id + '/'
      axios.get(url).then(response => {
        self.playlist = response.data
        axios
          .get(url + 'tracks/')
          .then(response => {
            self.updatePlts(response.data.results)
          })
          .then(() => {
            self.isLoading = false
          })
      })
    },
    deletePlaylist () {
      const self = this
      const url = 'playlists/' + this.id + '/'
      axios.delete(url).then(response => {
        self.$store.dispatch('playlists/fetchOwn')
        self.$router.push({
          path: '/library'
        })
      })
    }
  }
}
</script>
