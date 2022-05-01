<script setup lang="ts">
import AudioPlayer from '~/components/audio/Player.vue'
import Queue from '~/components/Queue.vue'
import PlaylistModal from '~/components/playlists/PlaylistModal.vue'
import ChannelUploadModal from '~/components/channels/UploadModal.vue'
import Sidebar from '~/components/Sidebar.vue'
import ServiceMessages from '~/components/ServiceMessages.vue'
import SetInstanceModal from '~/components/SetInstanceModal.vue'
import ShortcutsModal from '~/components/ShortcutsModal.vue'
import FilterModal from '~/components/moderation/FilterModal.vue'
import ReportModal from '~/components/moderation/ReportModal.vue'
import { useIntervalFn, useToggle, useWindowSize } from '@vueuse/core'

import { computed, nextTick, onMounted, ref, watchEffect } from 'vue'
import store from '~/store'
import {
  ListenWSEvent,
  PendingReviewEditsWSEvent,
  PendingReviewReportsWSEvent,
  PendingReviewRequestsWSEvent,
  Track
} from '~/types'
import useWebSocketHandler from '~/composables/useWebSocketHandler'
import { getClientOnlyRadio } from '~/radios'
import onKeyboardShortcut from '~/composables/onKeyboardShortcut'

// Tracks
const currentTrack = computed(() => store.getters['queue/currentTrack'])
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
  return store.state.instance?.frontSettings?.additionalStylesheets ?? []
})

// Fake content
onMounted(async () => {
  await nextTick()
  document.getElementById('fake-content')?.classList.add('loaded')
})

// WebSocket handlers
useWebSocketHandler('inbox.item_added', () => {
  store.commit('ui/incrementNotifications', { type: 'inbox', count: 1 })
})

useWebSocketHandler('mutation.created', (event) => {
  store.commit('ui/incrementNotifications', {
    type: 'pendingReviewEdits',
    value: (event as PendingReviewEditsWSEvent).pending_review_count
  })
})

useWebSocketHandler('mutation.updated', (event) => {
  store.commit('ui/incrementNotifications', {
    type: 'pendingReviewEdits',
    value: (event as PendingReviewEditsWSEvent).pending_review_count
  })
})

useWebSocketHandler('report.created', (event) => {
  store.commit('ui/incrementNotifications', {
    type: 'pendingReviewReports',
    value: (event as PendingReviewReportsWSEvent).unresolved_count
  })
})

useWebSocketHandler('user_request.created', (event) => {
  store.commit('ui/incrementNotifications', {
    type: 'pendingReviewRequests',
    value: (event as PendingReviewRequestsWSEvent).pending_count
  })
})

useWebSocketHandler('Listen', (event) => {
  if (store.state.radios.current && store.state.radios.running) {
    const { current } = store.state.radios

    if (current.clientOnly && current.type === 'account') {
      getClientOnlyRadio(current).handleListen(current, event as ListenWSEvent, store)
    }
  }
})

// Time ago
// TODO (wvffle): Migrate to useTimeAgo
useIntervalFn(() => {
  // used to redraw ago dates every minute
  store.commit('ui/computeLastDate')
}, 1000 * 60)

// Shortcuts
const [showShortcutsModal, toggleShortcutsModal] = useToggle(false)
onKeyboardShortcut('h', () => toggleShortcutsModal())

const { width } = useWindowSize()
const player = ref()
const showSetInstanceModal = ref(false)
</script>

<template>
  <div
    id="app"
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
      <queue
        v-if="store.state.ui.queueFocused"
        @touch-progress="player.setCurrentTime($event)"
      />
    </transition>

    <router-view
      v-slot="{ Component }"
      role="main"
    >
      <template v-if="Component">
        <Suspense>
          <component :is="Component" />
          <template #fallback>
            <!-- TODO (wvffle): Add loader -->
            Loading...
          </template>
        </Suspense>
      </template>
    </router-view>

    <audio-player ref="player" />
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
