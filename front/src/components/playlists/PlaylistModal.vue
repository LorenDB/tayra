<template>
  <modal
    :show="$store.state.playlists.showModal"
    @update:show="update"
  >
    <h4 class="header">
      <template v-if="track">
        <h2 class="ui header">
          <translate translate-context="Popup/Playlist/Title/Verb">
            Add to playlist
          </translate>
          <div
            v-translate="{artist: track.artist.name, title: track.title}"
            class="ui sub header"
            translate-context="Popup/Playlist/Paragraph"
            :translate-params="{artist: track.artist.name, title: track.title}"
          >
            "%{ title }", by %{ artist }
          </div>
        </h2>
      </template>
      <translate
        v-else
        translate-context="Popup/Playlist/Title/Verb"
      >
        Manage playlists
      </translate>
    </h4>
    <div class="scrolling content">
      <playlist-form :key="formKey" />
      <div class="ui divider" />
      <div v-if="playlists.length > 0">
        <div
          v-if="showDuplicateTrackAddConfirmation"
          role="alert"
          class="ui warning message"
        >
          <p
            v-translate="{track: track.title, playlist: duplicateTrackAddInfo.playlist_name}"
            translate-context="Popup/Playlist/Paragraph"
            :translate-params="{track: track.title, playlist: duplicateTrackAddInfo.playlist_name}"
          >
            <strong>%{ track }</strong> is already in <strong>%{ playlist }</strong>.
          </p>
          <button
            class="ui small basic cancel button"
            @click="duplicateTrackAddConfirm(false)"
          >
            <translate translate-context="*/*/Button.Label/Verb">
              Cancel
            </translate>
          </button>
          <button
            class="ui small success button"
            @click="addToPlaylist(lastSelectedPlaylist, true)"
          >
            <translate translate-context="*/Playlist/Button.Label/Verb">
              Add anyways
            </translate>
          </button>
        </div>
        <div
          v-if="errors.length > 0"
          role="alert"
          class="ui negative message"
        >
          <h4 class="header">
            <translate translate-context="Popup/Playlist/Error message.Title">
              The track can't be added to a playlist
            </translate>
          </h4>
          <ul class="list">
            <li
              v-for="(error, key) in errors"
              :key="key"
            >
              {{ error }}
            </li>
          </ul>
        </div>
        <h4 class="ui header">
          <translate translate-context="Popup/Playlist/Title">
            Available playlists
          </translate>
        </h4>
        <div class="ui form">
          <div class="fields">
            <div class="field">
              <label for="playlist-name-filter"><translate translate-context="Popup/Playlist/Label">Filter</translate></label>
              <input
                id="playlist-name-filter"
                v-model="playlistNameFilter"
                type="text"
                class="inline"
                :placeholder="labels.filterPlaylistField"
              >
            </div>
          </div>
        </div>
        <table
          v-if="sortedPlaylists.length > 0"
          class="ui unstackable very basic table"
        >
          <thead>
            <tr>
              <th><span class="visually-hidden"><translate translate-context="*/*/*/Verb">Edit</translate></span></th>
              <th>
                <translate translate-context="*/*/*/Noun">
                  Name
                </translate>
              </th>
              <th class="sorted descending">
                <translate translate-context="Popup/Playlist/Table.Label/Short">
                  Last modification
                </translate>
              </th>
              <th>
                <translate translate-context="*/*/*">
                  Tracks
                </translate>
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="(playlist, key) in sortedPlaylists"
              :key="key"
            >
              <td>
                <router-link
                  class="ui icon basic small button"
                  :to="{name: 'library.playlists.detail', params: {id: playlist.id }, query: {mode: 'edit'}}"
                >
                  <i class="ui pencil icon" />
                  <span class="visually-hidden"><translate translate-context="*/*/*/Verb">Edit</translate></span>
                </router-link>
              </td>
              <td>
                <router-link
                  :to="{name: 'library.playlists.detail', params: {id: playlist.id }}"
                  @click.native="update(false)"
                >
                  {{ playlist.name }}
                </router-link>
              </td>
              <td><human-date :date="playlist.modification_date" /></td>
              <td>{{ playlist.tracks_count }}</td>
              <td>
                <button
                  v-if="track"
                  class="ui success icon basic small right floated button"
                  :title="labels.addToPlaylist"
                  @click.prevent="addToPlaylist(playlist.id, false)"
                >
                  <i class="plus icon" /> <translate translate-context="Popup/Playlist/Table.Button.Label/Verb">
                    Add track
                  </translate>
                </button>
              </td>
            </tr>
          </tbody>
        </table>
        <template v-else>
          <div class="ui small placeholder segment component-placeholder">
            <h4 class="ui header">
              <translate translate-context="Popup/Playlist/EmptyState">
                No results matching your filter
              </translate>
            </h4>
          </div>
        </template>
      </div>
      <template v-else>
        <div class="ui placeholder segment">
          <div class="ui icon header">
            <i class="list icon" />
            <translate translate-context="Content/Home/Placeholder">
              No playlists have been created yet
            </translate>
          </div>
        </div>
      </template>
    </div>
    <div class="actions">
      <button class="ui basic cancel button">
        <translate translate-context="*/*/Button.Label/Verb">
          Cancel
        </translate>
      </button>
    </div>
  </modal>
</template>

<script>
import { filter, sortBy, flow } from 'lodash-es'

import axios from 'axios'
import { mapState } from 'vuex'

import logger from '~/logging'
import Modal from '~/components/semantic/Modal.vue'
import PlaylistForm from '~/components/playlists/Form.vue'
import { onBeforeRouteLeave, onBeforeRouteUpdate } from 'vue-router'

export default {
  components: {
    Modal,
    PlaylistForm
  },
  setup () {
    const guard = () => {
      this.$store.commit('playlists/showModal', false)
      this.showDuplicateTrackAddConfirmation = false
    }

    onBeforeRouteUpdate(guard)
    onBeforeRouteLeave(guard)
  },
  data () {
    return {
      formKey: String(new Date()),
      errors: [],
      playlistNameFilter: '',
      duplicateTrackAddInfo: {},
      showDuplicateTrackAddConfirmation: false,
      lastSelectedPlaylist: -1
    }
  },
  computed: {
    ...mapState({
      playlists: state => state.playlists.playlists,
      track: state => state.playlists.modalTrack
    }),
    labels () {
      return {
        addToPlaylist: this.$pgettext('Popup/Playlist/Table.Button.Tooltip/Verb', 'Add to this playlist'),
        filterPlaylistField: this.$pgettext('Popup/Playlist/Form/Placeholder', 'Enter playlist name')
      }
    },
    sortedPlaylists () {
      const regexp = new RegExp(this.playlistNameFilter, 'i')
      const p = flow(
        filter((e) => e.name.match(regexp) !== null),
        sortBy((e) => { return e.modification_date })
      )(this.playlists)
      p.reverse()
      return p
    }
  },
  watch: {
    '$store.state.playlists.showModal' () {
      this.formKey = String(new Date())
      this.showDuplicateTrackAddConfirmation = false
    }
  },
  methods: {
    update (v) {
      this.$store.commit('playlists/showModal', v)
    },
    addToPlaylist (playlistId, allowDuplicate) {
      const self = this
      const payload = {
        tracks: [this.track.id],
        allow_duplicates: allowDuplicate
      }

      self.lastSelectedPlaylist = playlistId

      return axios.post(`playlists/${playlistId}/add`, payload).then(response => {
        logger.default.info('Successfully added track to playlist')
        self.update(false)
        self.$store.dispatch('playlists/fetchOwn')
      }, error => {
        if (error.backendErrors.length === 1 && error.backendErrors[0].code === 'tracks_already_exist_in_playlist') {
          self.duplicateTrackAddInfo = error.backendErrors[0]
          self.showDuplicateTrackAddConfirmation = true
        } else {
          self.errors = error.backendErrors
          self.showDuplicateTrackAddConfirmation = false
        }
      })
    },
    duplicateTrackAddConfirm (v) {
      this.showDuplicateTrackAddConfirmation = v
    }
  }
}
</script>
