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
import { useIntervalFn, useWindowSize } from '@vueuse/core'
import GlobalEvents from '~/components/utils/global-events.vue'

import { computed, nextTick, onMounted, ref, watchEffect } from '@vue/composition-api'
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
useIntervalFn(() => {
  // used to redraw ago dates every minute
  store.commit('ui/computeLastDate')
}, 1000 * 60)

const { width } = useWindowSize()
const player = ref()
const showShortcutsModal = ref(false)
const showSetInstanceModal = ref(false)
// export default {
//   computed: {
//     ...mapState({
//       serviceWorker: state => state.ui.serviceWorker
//     }),
//   },
//   watch: {
//     'serviceWorker.updateAvailable': {
//       handler (v) {
//         if (!v) {
//           return
//         }
//         const self = this
//         this.$store.commit('ui/addMessage', {
//           content: this.$pgettext('App/Message/Paragraph', 'A new version of the app is available.'),
//           date: new Date(),
//           key: 'refreshApp',
//           displayTime: 0,
//           classActions: 'bottom attached opaque',
//           actions: [
//             {
//               text: this.$pgettext('App/Message/Paragraph', 'Update'),
//               class: 'primary',
//               click: function () {
//                 self.updateApp()
//               }
//             },
//             {
//               text: this.$pgettext('App/Message/Paragraph', 'Later'),
//               class: 'basic'
//             }
//           ]
//         })
//       },
//       immediate: true
//     }
//   },
//   async created () {
//     if (navigator.serviceWorker) {
//       navigator.serviceWorker.addEventListener(
//         'controllerchange', () => {
//           if (this.serviceWorker.refreshing) return
//           this.$store.commit('ui/serviceWorker', {
//             refreshing: true
//           })
//           window.location.reload()
//         }
//       )
//     }
//   },
//   methods: {
//     updateApp () {
//       this.$store.commit('ui/serviceWorker', { updateAvailable: false })
//       if (!this.serviceWorker.registration || !this.serviceWorker.registration.waiting) { return }
//       this.serviceWorker.registration.waiting.postMessage({ command: 'skipWaiting' })
//     },
//   }
// }
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
      @show:shortcuts-modal="showShortcutsModal = !showShortcutsModal"
    />
    <set-instance-modal
      :show="showSetInstanceModal"
      @update:show="showSetInstanceModal = $event"
    />
    <service-messages />
    <transition name="queue">
      <queue
        v-if="store.state.ui.queueFocused"
        @touch-progress="player.setCurrentTime($event)"
      />
    </transition>
    <router-view
      role="main"
      :class="{hidden: store.state.ui.queueFocused}"
    />
    <audio-player ref="player" />
    <playlist-modal v-if="store.state.auth.authenticated" />
    <channel-upload-modal v-if="store.state.auth.authenticated" />
    <filter-modal v-if="store.state.auth.authenticated" />
    <report-modal />
    <shortcuts-modal
      :show="showShortcutsModal"
      @update:show="showShortcutsModal = $event"
    />
    <GlobalEvents @keydown.h.exact="showShortcutsModal = !showShortcutsModal" />
  </div>
</template>

<style lang="scss">
@import "style/_main";
</style>
