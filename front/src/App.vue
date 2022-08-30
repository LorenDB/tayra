<script setup lang="ts">
import type { Track } from '~/types'

import { useIntervalFn, useToggle, useWindowSize } from '@vueuse/core'
import { computed, nextTick, onMounted, ref, watchEffect } from 'vue'
import { useStore } from '~/store'

import ChannelUploadModal from '~/components/channels/UploadModal.vue'
import PlaylistModal from '~/components/playlists/PlaylistModal.vue'
import FilterModal from '~/components/moderation/FilterModal.vue'
import ReportModal from '~/components/moderation/ReportModal.vue'
import SetInstanceModal from '~/components/SetInstanceModal.vue'
import ServiceMessages from '~/components/ServiceMessages.vue'
import ShortcutsModal from '~/components/ShortcutsModal.vue'
import AudioPlayer from '~/components/audio/Player.vue'
import Sidebar from '~/components/Sidebar.vue'
import Queue from '~/components/Queue.vue'

import onKeyboardShortcut from '~/composables/onKeyboardShortcut'
import useQueue from '~/composables/audio/useQueue'

const store = useStore()

// Tracks
const { currentTrack } = useQueue()
const getTrackInformationText = (track: Track | undefined) => {
  if (!track) {
    return null
  }

  const artist = track.artist ?? track.album?.artist
  return `♫ ${track.title} – ${artist?.name} ♫`
}

// Update title
const initialTitle = document.title
watchEffect(() => {
  const parts = [
    getTrackInformationText(currentTrack.value),
    store.state.ui.pageTitle,
    initialTitle || 'Funkwhale'
  ]

  document.title = parts.filter(i => i).join(' – ')
})

// Styles
const customStylesheets = computed(() => {
  return store.state.instance.frontSettings.additionalStylesheets ?? []
})

// Fake content
onMounted(async () => {
  await nextTick()
  document.getElementById('fake-content')?.classList.add('loaded')
})

// Time ago
useIntervalFn(() => {
  // used to redraw ago dates every minute
  store.commit('ui/computeLastDate')
}, 1000 * 60)

// Shortcuts
const [showShortcutsModal, toggleShortcutsModal] = useToggle(false)
onKeyboardShortcut('h', () => toggleShortcutsModal())

const { width } = useWindowSize()
const showSetInstanceModal = ref(false)

// Fetch user data on startup
// NOTE: We're not checking if we're authenticated in the store,
//       because we want to learn if we are authenticated at all
store.dispatch('auth/fetchUser')
</script>

<template>
  <div
    :key="String(store.state.instance.instanceUrl)"
    :class="[store.state.ui.queueFocused ? 'queue-focused' : '',
             {'has-bottom-player': store.state.queue.tracks.length > 0}]"
  >
    <!-- here, we display custom stylesheets, if any -->
    <link
      v-for="url in customStylesheets"
      :key="url"
      rel="stylesheet"
      property="stylesheet"
      :href="url"
    >

    <sidebar
      :width="width"
      @show:set-instance-modal="showSetInstanceModal = !showSetInstanceModal"
      @show:shortcuts-modal="toggleShortcutsModal"
    />
    <set-instance-modal v-model:show="showSetInstanceModal" />
    <service-messages />
    <transition name="queue">
      <queue v-show="store.state.ui.queueFocused" />
    </transition>

    <router-view v-slot="{ Component }">
      <template v-if="Component">
        <keep-alive :max="1">
          <Suspense>
            <component :is="Component" />
            <template #fallback>
              <!-- TODO (wvffle): Add loader -->
              Loading...
            </template>
          </Suspense>
        </keep-alive>
      </template>
    </router-view>

    <audio-player />
    <playlist-modal v-if="store.state.auth.authenticated" />
    <channel-upload-modal v-if="store.state.auth.authenticated" />
    <filter-modal v-if="store.state.auth.authenticated" />
    <report-modal />
    <shortcuts-modal v-model:show="showShortcutsModal" />
  </div>
</template>

<style lang="scss">
@import "style/_main";
</style>
