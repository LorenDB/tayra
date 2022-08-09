<script setup lang="ts">
import type { PlaylistTrack, Playlist } from '~/types'

import { useGettext } from 'vue3-gettext'
import { useRouter } from 'vue-router'
import { ref, computed } from 'vue'
import { useStore } from '~/store'

import axios from 'axios'

import PlaylistEditor from '~/components/playlists/Editor.vue'
import EmbedWizard from '~/components/audio/EmbedWizard.vue'
import SemanticModal from '~/components/semantic/Modal.vue'
import TrackTable from '~/components/audio/track/Table.vue'
import PlayButton from '~/components/audio/PlayButton.vue'

import useErrorHandler from '~/composables/useErrorHandler'

interface Props {
  id: string
  defaultEdit?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  defaultEdit: false
})

const store = useStore()
const router = useRouter()

const edit = ref(props.defaultEdit)
const playlist = ref<Playlist | null>(null)
const playlistTracks = ref<PlaylistTrack[]>([])

const showEmbedModal = ref(false)

const tracks = computed(() => playlistTracks.value.map(({ track }, index) => ({ ...track, position: index + 1 })))

const { $pgettext } = useGettext()
const labels = computed(() => ({
  playlist: $pgettext('*/*/*', 'Playlist')
}))

const isLoading = ref(false)
const fetchData = async () => {
  isLoading.value = true

  try {
    const [playlistResponse, tracksResponse] = await Promise.all([
      axios.get(`playlists/${props.id}/`),
      axios.get(`playlists/${props.id}/tracks/`)
    ])

    playlist.value = playlistResponse.data
    playlistTracks.value = tracksResponse.data.results
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoading.value = false
}

fetchData()

const deletePlaylist = async () => {
  try {
    await axios.delete(`playlists/${props.id}/`)
    store.dispatch('playlists/fetchOwn')
    return router.push({ path: '/library' })
  } catch (error) {
    useErrorHandler(error as Error)
  }
}
</script>

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
              v-if="$store.state.auth.profile && playlist.user.id === $store.state.auth.profile?.id"
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
              <template #modal-header>
                <p
                  v-translate="{playlist: playlist.name}"
                  translate-context="Popup/Playlist/Title/Call to action"
                  :translate-params="{playlist: playlist.name}"
                >
                  Do you want to delete the playlist "%{ playlist }"?
                </p>
              </template>
              <template #modal-content>
                <p>
                  <translate translate-context="Popup/Playlist/Paragraph">
                    This will completely delete this playlist and cannot be undone.
                  </translate>
                </p>
              </template>
              <template #modal-confirm>
                <div>
                  <translate translate-context="Popup/Playlist/Button.Label/Verb">
                    Delete playlist
                  </translate>
                </div>
              </template>
            </dangerous-button>
          </div>
        </div>
        <semantic-modal
          v-if="playlist.privacy_level === 'everyone' && playlist.is_playable"
          v-model:show="showEmbedModal"
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
        </semantic-modal>
      </div>
    </section>
    <section class="ui vertical stripe segment">
      <template v-if="edit">
        <playlist-editor
          v-model:playlist="playlist"
          v-model:playlist-tracks="playlistTracks"
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
          :unique="false"
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
