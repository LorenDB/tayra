<script setup lang="ts">
import type { Playlist, Track, PlaylistTrack, BackendError, APIErrorResponse } from '~/types'

import { useStore } from '~/store'
import { useGettext } from 'vue3-gettext'
import { computed, ref } from 'vue'
import axios from 'axios'
import PlaylistForm from '~/components/playlists/Form.vue'
import draggable from 'vuedraggable'
import { useVModels } from '@vueuse/core'
import useQueue from '~/composables/audio/useQueue'

interface Props {
  playlist: Playlist | null
  playlistTracks: PlaylistTrack[]
}

const props = defineProps<Props>()

const emit = defineEmits(['update:playlist', 'update:playlistTracks'])
const { playlistTracks, playlist } = useVModels(props, emit)

const errors = ref([] as string[])
const duplicateTrackAddInfo = ref<APIErrorResponse | null>(null)
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

const { $pgettext } = useGettext()
const labels = computed(() => ({
  copyTitle: $pgettext('Content/Playlist/Button.Tooltip/Verb', 'Copy the current queue to this playlist')
}))

const isLoading = ref(false)
const status = computed(() => isLoading.value
  ? 'loading'
  : errors.value.length
    ? 'errored'
    : showDuplicateTrackAddConfirmation.value
      ? 'confirmDuplicateAdd'
      : 'saved'
)

const responseHandlers = {
  success () {
    errors.value = []
    showDuplicateTrackAddConfirmation.value = false
  },
  errored (error: BackendError): void {
    const { backendErrors, rawPayload } = error
    // if backendErrors isn't populated (e.g. duplicate track exceptions raised by
    // the playlist model), read directly from the response
    // TODO (wvffle): Check if such case exists after rewrite
    if (error.rawPayload?.playlist) {
      error.backendErrors = error.rawPayload.playlist as string[]
      error.rawPayload = undefined
      return this.errored(error)
    }

    // TODO (wvffle): Test if it works
    // if (errors.length === 1 && errors[0].code === 'tracks_already_exist_in_playlist') {
    if (backendErrors.length === 1 && backendErrors[0] === 'Tracks already exist in playlist') {
      duplicateTrackAddInfo.value = rawPayload ?? null
      showDuplicateTrackAddConfirmation.value = true
      return
    }

    errors.value = backendErrors
  }
}

const store = useStore()
const reorder = async ({ oldIndex: from, newIndex: to }: { oldIndex: number, newIndex: number }) => {
  isLoading.value = true

  try {
    await axios.post(`playlists/${playlist.value!.id}/move/`, { from, to })
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
    await axios.post(`playlists/${playlist.value!.id}/remove/`, { index })
    await store.dispatch('playlists/fetchOwn')
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
    await axios.post(`playlists/${playlist.value!.id}/clear/`)
    await store.dispatch('playlists/fetchOwn')
    responseHandlers.success()
  } catch (error) {
    responseHandlers.errored(error as BackendError)
  }

  isLoading.value = false
}

const insertMany = async (insertedTracks: Track[], allowDuplicates: boolean) => {
  isLoading.value = true

  try {
    const response = await axios.post(`playlists/${playlist.value!.id}/add/`, {
      allow_duplicates: allowDuplicates,
      tracks: insertedTracks.map(track => track.id)
    })

    tracks.value.push(...response.data.results)
    await store.dispatch('playlists/fetchOwn')
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
      :title="false"
      v-model:playlist="playlist"
    />
    <h3 class="ui top attached header">
      <translate translate-context="Content/Playlist/Title">
        Playlist editor
      </translate>
    </h3>
    <div class="ui attached segment">
      <template v-if="status === 'loading'">
        <div class="ui active tiny inline loader" />
        <translate translate-context="Content/Playlist/Paragraph">
          Syncing changes to server…
        </translate>
      </template>
      <template v-else-if="status === 'errored'">
        <i class="dangerclose icon" />
        <translate translate-context="Content/Playlist/Error message.Title">
          An error occurred while saving your changes
        </translate>
        <div
          v-if="errors.length > 0"
          role="alert"
          class="ui negative message"
        >
          <ul class="list">
            <li
              v-for="(error, key) in errors"
              :key="key"
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
        <p
          v-translate="{playlist: playlist?.name}"
          translate-context="Content/Playlist/Paragraph"
        >
          Some tracks in your queue are already in this playlist:
        </p>
        <ul class="ui relaxed divided list duplicate-tracks-list">
          <li
            v-for="(track, key) in duplicateTrackAddInfo?.tracks ?? []"
            :key="key"
            class="ui item"
          >
            {{ track }}
          </li>
        </ul>
        <button
          class="ui small success button"
          @click="insertMany(queueTracks, true)"
        >
          <translate translate-context="*/Playlist/Button.Label/Verb">
            Add anyways
          </translate>
        </button>
      </div>
      <template v-else-if="status === 'saved'">
        <i class="success check icon" /> <translate translate-context="Content/Playlist/Paragraph">
          Changes synced with server
        </translate>
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
        <translate
          translate-context="Content/Playlist/Button.Label/Verb"
          translate-plural="Insert from queue (%{ count } tracks)"
          :translate-n="queueTracks.length"
          :translate-params="{count: queueTracks.length}"
        >
          Insert from queue (%{ count } track)
        </translate>
      </button>

      <dangerous-button
        :disabled="tracks.length === 0"
        class="ui labeled right floated danger icon button"
        :action="clearPlaylist"
      >
        <i class="eraser icon" /> <translate translate-context="*/Playlist/Button.Label/Verb">
          Clear playlist
        </translate>
        <template #modal-header>
          <p
            v-translate="{playlist: playlist?.name}"
            translate-context="Popup/Playlist/Title"
            :translate-params="{playlist: playlist?.name}"
          >
            Do you want to clear the playlist "%{ playlist }"?
          </p>
        </template>
        <template #modal-content>
          <p>
            <translate translate-context="Popup/Playlist/Paragraph">
              This will remove all tracks from this playlist and cannot be undone.
            </translate>
          </p>
        </template>
        <template #modal-confirm>
          <div>
            <translate translate-context="*/Playlist/Button.Label/Verb">
              Clear playlist
            </translate>
          </div>
        </template>
      </dangerous-button>
      <div class="ui hidden divider" />
      <template v-if="tracks.length > 0">
        <p>
          <translate translate-context="Content/Playlist/Paragraph/Call to action">
            Drag and drop rows to reorder tracks in the playlist
          </translate>
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
