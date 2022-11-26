<script setup lang="ts">
import type { BackendError, Playlist, APIErrorResponse } from '~/types'

import { filter, sortBy, flow } from 'lodash-es'
import axios from 'axios'
import { useI18n } from 'vue-i18n'
import SemanticModal from '~/components/semantic/Modal.vue'
import PlaylistForm from '~/components/playlists/Form.vue'
import useLogger from '~/composables/useLogger'
import { useStore } from '~/store'
import { ref, computed, watch } from 'vue'
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

const { t } = useI18n()
const labels = computed(() => ({
  addToPlaylist: t('components.playlists.PlaylistModal.button.addToPlaylist'),
  filterPlaylistField: t('components.playlists.PlaylistModal.placeholder.filterPlaylist')
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
    await axios.post(`playlists/${playlistId}/add/`, {
      tracks: [track.value?.id].filter(i => i),
      allow_duplicates: allowDuplicates
    })

    logger.info('Successfully added track to playlist')
    store.state.playlists.showModal = false
    store.dispatch('playlists/fetchOwn')
  } catch (error) {
    if (error as BackendError) {
      const { backendErrors, rawPayload = {} } = error as BackendError

      if (backendErrors.length === 1 && backendErrors[0] === 'Tracks Already Exist In Playlist') {
        duplicateTrackAddInfo.value = ((rawPayload.playlist as APIErrorResponse).non_field_errors as APIErrorResponse)[0] as object
        showDuplicateTrackAddConfirmation.value = true
      } else {
        errors.value = backendErrors
        showDuplicateTrackAddConfirmation.value = false
      }
    }
  }
}

store.dispatch('playlists/fetchOwn')
</script>

<template>
  <semantic-modal
    v-model:show="$store.state.playlists.showModal"
  >
    <h4 class="header">
      <template v-if="track">
        <h2 class="ui header">
          {{ $t('components.playlists.PlaylistModal.header.addToPlaylist') }}
          <div class="ui sub header">
            {{ $t('components.playlists.PlaylistModal.header.track', {artist: track.artist?.name, title: track.title}) }}
          </div>
        </h2>
      </template>
      <span v-else>
        {{ $t('components.playlists.PlaylistModal.header.manage') }}
      </span>
    </h4>
    <div class="scrolling content">
      <playlist-form
        :key="formKey"
        :create="true"
      />
      <div class="ui divider" />
      <div v-if="playlists.length > 0">
        <div
          v-if="showDuplicateTrackAddConfirmation"
          role="alert"
          class="ui warning message"
        >
          <p>
            <i18n-t keypath="components.playlists.PlaylistModal.warning.duplicate">
              <strong>{{ track?.title }}</strong>
              <strong>{{ duplicateTrackAddInfo.playlist_name }}</strong>
            </i18n-t>
          </p>
          <button
            class="ui small basic cancel button"
            @click="showDuplicateTrackAddConfirmation = false"
          >
            {{ $t('components.playlists.PlaylistModal.button.cancel') }}
          </button>
          <button
            class="ui small success button"
            @click="addToPlaylist(lastSelectedPlaylist, true)"
          >
            {{ $t('components.playlists.PlaylistModal.button.addDuplicate') }}
          </button>
        </div>
        <div
          v-if="errors.length > 0"
          role="alert"
          class="ui negative message"
        >
          <h4 class="header">
            {{ $t('components.playlists.PlaylistModal.header.addFailure') }}
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
          {{ $t('components.playlists.PlaylistModal.header.available') }}
        </h4>
        <div class="ui form">
          <div class="fields">
            <div class="field">
              <label for="playlist-name-filter">{{ $t('components.playlists.PlaylistModal.label.filter') }}</label>
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
              <th><span class="visually-hidden">{{ $t('components.playlists.PlaylistModal.table.edit.header.edit') }}</span></th>
              <th>
                {{ $t('components.playlists.PlaylistModal.table.edit.header.name') }}
              </th>
              <th class="sorted descending">
                {{ $t('components.playlists.PlaylistModal.table.edit.header.lastModification') }}
              </th>
              <th>
                {{ $t('components.playlists.PlaylistModal.table.edit.header.tracks') }}
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
                  <span class="visually-hidden">{{ $t('components.playlists.PlaylistModal.button.edit') }}</span>
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
                  <i class="plus icon" />
                  {{ $t('components.playlists.PlaylistModal.button.addTrack') }}
                </button>
              </td>
            </tr>
          </tbody>
        </table>
        <template v-else>
          <div class="ui small placeholder segment component-placeholder">
            <h4 class="ui header">
              {{ $t('components.playlists.PlaylistModal.header.noResults') }}
            </h4>
          </div>
        </template>
      </div>
      <div
        v-else
        class="ui placeholder segment"
      >
        <div class="ui icon header">
          <i class="list icon" />
          {{ $t('components.playlists.PlaylistModal.empty.noPlaylists') }}
        </div>
      </div>
    </div>
    <div class="actions">
      <button class="ui basic cancel button">
        {{ $t('components.playlists.PlaylistModal.button.cancel') }}
      </button>
    </div>
  </semantic-modal>
</template>
