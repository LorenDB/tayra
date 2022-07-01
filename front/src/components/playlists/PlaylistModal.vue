<script setup lang="ts">
import { filter, sortBy, flow } from 'lodash-es'

import axios from 'axios'
import { useGettext } from 'vue3-gettext'

import Modal from '~/components/semantic/Modal.vue'
import PlaylistForm from '~/components/playlists/Form.vue'
import useLogger from '~/composables/useLogger'
import { useStore } from '~/store'
import { ref, computed, watch } from 'vue'
import { BackendError, Playlist, APIErrorResponse } from '~/types'
import { useRouter } from 'vue-router'

const logger = useLogger()
const store = useStore()

const showDuplicateTrackAddConfirmation = ref(false)

const router = useRouter()
router.beforeEach(() => {
  store.commit('playlists/showModal', false)
  showDuplicateTrackAddConfirmation.value = false
})

const playlists = computed(() => store.state.playlists.playlists)
const track = computed(() => store.state.playlists.modalTrack)

const { $pgettext } = useGettext()
const labels = computed(() => ({ 
  addToPlaylist: $pgettext('Popup/Playlist/Table.Button.Tooltip/Verb', 'Add to this playlist'),
  filterPlaylistField: $pgettext('Popup/Playlist/Form/Placeholder', 'Enter playlist name')
}))

const playlistNameFilter = ref('')

const sortedPlaylists = computed(() => flow(
  filter((playlist: Playlist) => playlist.name.match(new RegExp(playlistNameFilter.value, 'i')) !== null),
  sortBy((playlist: Playlist) => { return playlist.modification_date })
)(playlists.value).reverse())

const formKey = ref(new Date().toString())
watch(() => store.state.playlists.showModal, () => {
      formKey.value = new Date().toString()
      showDuplicateTrackAddConfirmation.value = false
})

const lastSelectedPlaylist = ref(-1)
const errors = ref([] as string[])
const duplicateTrackAddInfo = ref({} as { playlist_name?: string })

const addToPlaylist = async (playlistId: number, allowDuplicates: boolean) => {
  lastSelectedPlaylist.value = playlistId

  try { 
    await axios.post(`playlists/${playlistId}/add`, {
      tracks: [track.value?.id].filter(i => i),
      allow_duplicates: allowDuplicates
    })

    logger.info('Successfully added track to playlist')
    store.state.playlists.showModal = false
    store.dispatch('playlists/fetchOwn')
  } catch (error) {
    if (error as BackendError) {
      const { backendErrors, rawPayload = {} } = error as BackendError

      // TODO (wvffle): Test if it works
      // if (backendErrors.length === 1 && backendErrors[0].code === 'tracks_already_exist_in_playlist') {
      if (backendErrors.length === 1 && backendErrors[0] === 'Tracks already exist in playlist') {
        duplicateTrackAddInfo.value = ((rawPayload.playlist as APIErrorResponse).non_field_errors as APIErrorResponse)[0] as object
        showDuplicateTrackAddConfirmation.value = true
      } else {
        errors.value = backendErrors
        showDuplicateTrackAddConfirmation.value = false
      }
    }
  }
}
</script>

<template>
  <modal
    v-model:show="$store.state.playlists.showModal"
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
            v-translate="{track: track?.title, playlist: duplicateTrackAddInfo.playlist_name}"
            translate-context="Popup/Playlist/Paragraph"
            :translate-params="{track: track?.title, playlist: duplicateTrackAddInfo.playlist_name}"
          >
            <strong>%{ track }</strong> is already in <strong>%{ playlist }</strong>.
          </p>
          <button
            class="ui small basic cancel button"
            @click="showDuplicateTrackAddConfirmation = false"
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
                  @click="$store.state.playlists.showModal = false"
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
