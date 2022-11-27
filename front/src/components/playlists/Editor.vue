<script setup lang="ts">
import type { Playlist, PlaylistTrack, BackendError, APIErrorResponse } from '~/types'

import { useI18n } from 'vue-i18n'
import { useVModels } from '@vueuse/core'
import { computed, ref } from 'vue'

import { useQueue } from '~/composables/audio/queue'
import { useStore } from '~/store'

import draggable from 'vuedraggable'
import axios from 'axios'

import PlaylistForm from '~/components/playlists/Form.vue'

interface Events {
  (e: 'update:playlistTracks', value: PlaylistTrack[]): void
  (e: 'update:playlist', value: Playlist): void
}

interface Props {
  playlist: Playlist | null
  playlistTracks: PlaylistTrack[]
}

const emit = defineEmits<Events>()
const props = defineProps<Props>()

const { playlistTracks, playlist } = useVModels(props, emit)

const errors = ref([] as string[])
const duplicateTrackAddInfo = ref<{ tracks: string[] }>()
const showDuplicateTrackAddConfirmation = ref(false)

const { tracks: queueTracks } = useQueue()

interface ModifiedPlaylistTrack extends PlaylistTrack {
  _id?: string
}

const tracks = computed({
  get: () => playlistTracks.value.map((playlistTrack, index) => ({ ...playlistTrack, _id: `${index}-${playlistTrack.track.id}` } as ModifiedPlaylistTrack)),
  set: (playlist) => {
    playlistTracks.value = playlist.map((modifiedPlaylistTrack, index) => {
      const res = { ...modifiedPlaylistTrack, index } as ModifiedPlaylistTrack
      delete res._id
      return res as PlaylistTrack
    })
  }
})

const { t } = useI18n()
const labels = computed(() => ({
  copyTitle: t('components.playlists.Editor.button.copy')
}))

const isLoading = ref(false)
const status = computed(() => isLoading.value
  ? 'loading'
  : showDuplicateTrackAddConfirmation.value
    ? 'confirmDuplicateAdd'
    : errors.value.length > 0
      ? 'errored'
      : 'saved'
)

const responseHandlers = {
  success () {
    errors.value = []
    showDuplicateTrackAddConfirmation.value = false
  },
  errored (error: BackendError): void {
    showDuplicateTrackAddConfirmation.value = false

    const { backendErrors, rawPayload = {} } = error
    if (backendErrors.length === 1 && backendErrors[0] === 'Tracks Already Exist In Playlist') {
      duplicateTrackAddInfo.value = ((rawPayload.playlist as APIErrorResponse).non_field_errors as APIErrorResponse)[0] as { tracks: string[] }
      showDuplicateTrackAddConfirmation.value = true
      return
    }

    errors.value = backendErrors
  }
}

const fetchTracks = async () => {
  // NOTE: This is handled by other functions and never used directly
  const response = await axios.get(`playlists/${playlist.value?.id}/tracks/`)
  playlistTracks.value = response.data.results
}

const store = useStore()
const reorder = async ({ oldIndex: from, newIndex: to }: { oldIndex: number, newIndex: number }) => {
  isLoading.value = true

  try {
    await axios.post(`playlists/${playlist.value?.id}/move/`, { from, to })
    await store.dispatch('playlists/fetchOwn')
    responseHandlers.success()
  } catch (error) {
    responseHandlers.errored(error as BackendError)
  }

  isLoading.value = false
}

const removePlaylistTrack = async (index: number) => {
  isLoading.value = true

  try {
    tracks.value.splice(index, 1)
    await axios.post(`playlists/${playlist.value?.id}/remove/`, { index })
    await Promise.all([
      store.dispatch('playlists/fetchOwn'),
      fetchTracks()
    ])
    responseHandlers.success()
  } catch (error) {
    responseHandlers.errored(error as BackendError)
  }

  isLoading.value = false
}

const clearPlaylist = async () => {
  isLoading.value = true

  try {
    tracks.value = []
    await axios.delete(`playlists/${playlist.value?.id}/clear/`)
    await store.dispatch('playlists/fetchOwn')
    responseHandlers.success()
  } catch (error) {
    responseHandlers.errored(error as BackendError)
  }

  isLoading.value = false
}

const insertMany = async (insertedTracks: number[], allowDuplicates: boolean) => {
  isLoading.value = true

  try {
    const response = await axios.post(`playlists/${playlist.value?.id}/add/`, {
      allow_duplicates: allowDuplicates,
      tracks: insertedTracks
    })

    tracks.value.push(...response.data.results)
    await Promise.all([
      store.dispatch('playlists/fetchOwn'),
      fetchTracks()
    ])
    responseHandlers.success()
  } catch (error) {
    responseHandlers.errored(error as BackendError)
  }

  isLoading.value = false
}
</script>

<template>
  <div class="ui text container component-playlist-editor">
    <playlist-form
      v-model:playlist="playlist"
      :title="undefined"
    />
    <h3 class="ui top attached header">
      {{ $t('components.playlists.Editor.header.editor') }}
    </h3>
    <div class="ui attached segment">
      <template v-if="status === 'loading'">
        <div class="ui active tiny inline loader" />
        {{ $t('components.playlists.Editor.loading.sync') }}
      </template>
      <template v-else-if="status === 'errored'">
        <i class="dangerclose icon" />
        {{ $t('components.playlists.Editor.error.sync') }}
        <div
          v-if="errors.length > 0"
          role="alert"
          class="ui negative message"
        >
          <ul class="list">
            <li
              v-for="error in errors"
              :key="error"
            >
              {{ error }}
            </li>
          </ul>
        </div>
      </template>
      <div
        v-else-if="status === 'confirmDuplicateAdd'"
        role="alert"
        class="ui warning message"
      >
        <p>
          {{ $t('components.playlists.Editor.warning.duplicate') }}
        </p>
        <ul class="ui relaxed divided list duplicate-tracks-list">
          <li
            v-for="track in duplicateTrackAddInfo?.tracks ?? []"
            :key="track"
            class="ui item"
          >
            {{ track }}
          </li>
        </ul>
        <button
          class="ui small success button"
          @click="insertMany(queueTracks, true)"
        >
          {{ $t('components.playlists.Editor.button.addDuplicate') }}
        </button>
      </div>
      <template v-else-if="status === 'saved'">
        <i class="success check icon" />
        {{ $t('components.playlists.Editor.message.sync') }}
      </template>
    </div>
    <div class="ui bottom attached segment">
      <button
        :disabled="queueTracks.length === 0"
        :class="['ui', {disabled: queueTracks.length === 0}, 'labeled', 'icon', 'button']"
        :title="labels.copyTitle"
        @click="insertMany(queueTracks, false)"
      >
        <i class="plus icon" />
        {{ $t('components.playlists.Editor.button.insertFromQueue', queueTracks.length) }}
      </button>

      <dangerous-button
        :disabled="tracks.length === 0"
        class="ui labeled right floated danger icon button"
        :action="clearPlaylist"
      >
        <i class="eraser icon" />
        {{ $t('components.playlists.Editor.button.clear') }}
        <template #modal-header>
          <p>
            {{ $t('components.playlists.Editor.modal.clearPlaylist.header', {playlist: playlist?.name}) }}
          </p>
        </template>
        <template #modal-content>
          <p>
            {{ $t('components.playlists.Editor.modal.clearPlaylist.content.warning') }}
          </p>
        </template>
        <template #modal-confirm>
          <div>
            {{ $t('components.playlists.Editor.button.clear') }}
          </div>
        </template>
      </dangerous-button>
      <div class="ui hidden divider" />
      <template v-if="tracks.length > 0">
        <p>
          {{ $t('components.playlists.Editor.help.reorder') }}
        </p>
        <div class="table-wrapper">
          <table class="ui compact very basic unstackable table">
            <draggable
              v-model="tracks"
              tag="tbody"
              item-key="_id"
              @update="reorder"
            >
              <template #item="{ element: plt, index }">
                <tr>
                  <td class="left aligned">
                    {{ plt.index + 1 }}
                  </td>
                  <td class="center aligned">
                    <img
                      v-if="plt.track.album && plt.track.album.cover && plt.track.album.cover.urls.original"
                      v-lazy="$store.getters['instance/absoluteUrl'](plt.track.album.cover.urls.medium_square_crop)"
                      alt=""
                      class="ui mini image"
                    >
                    <img
                      v-else
                      alt=""
                      class="ui mini image"
                      src="../../assets/audio/default-cover.png"
                    >
                  </td>
                  <td colspan="4">
                    <strong>{{ plt.track.title }}</strong><br>
                    {{ plt.track.artist.name }}
                  </td>
                  <td class="right aligned">
                    <button
                      class="ui circular danger basic icon button"
                      @click.stop="removePlaylistTrack(index)"
                    >
                      <i
                        class="trash icon"
                      />
                    </button>
                  </td>
                </tr>
              </template>
            </draggable>
          </table>
        </div>
      </template>
    </div>
  </div>
</template>
