<script setup lang="ts">
import type { PlaylistTrack, Playlist } from '~/types'

import { useI18n } from 'vue-i18n'
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
  id: number
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

const { t } = useI18n()
const labels = computed(() => ({
  playlist: t('views.playlists.Detail.title')
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
              {{ $t('views.playlists.Detail.meta.tracks', { username: playlist.user.username }, playlist.tracks_count) }}
              <br>
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
              {{ $t('views.playlists.Detail.button.playAll') }}
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
                {{ $t('views.playlists.Detail.button.stopEdit') }}
              </template>
              <template v-else>
                {{ $t('views.playlists.Detail.button.edit') }}
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
              {{ $t('views.playlists.Detail.button.embed') }}
            </button>
            <dangerous-button
              v-if="$store.state.auth.profile && playlist.user.id === $store.state.auth.profile.id"
              class="ui labeled danger icon button"
              :action="deletePlaylist"
            >
              <i class="trash icon" />
              {{ $t('views.playlists.Detail.button.delete') }}
              <template #modal-header>
                <p>
                  {{ $t('views.playlists.Detail.modal.delete.header', {playlist: playlist.name}) }}
                </p>
              </template>
              <template #modal-content>
                <p>
                  {{ $t('views.playlists.Detail.modal.delete.content.warning') }}
                </p>
              </template>
              <template #modal-confirm>
                <div>
                  {{ $t('views.playlists.Detail.button.confirm') }}
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
            {{ $t('views.playlists.Detail.modal.embed.header') }}
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
              {{ $t('views.playlists.Detail.button.cancel') }}
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
          {{ $t('views.playlists.Detail.header.tracks') }}
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
          {{ $t('views.playlists.Detail.empty.noTracks') }}
        </div>
        <button
          class="ui success icon labeled button"
          @click="edit = !edit"
        >
          <i class="pencil icon" />
          {{ $t('views.playlists.Detail.button.edit') }}
        </button>
      </div>
    </section>
  </main>
</template>
