<template>
  <div
    id="app"
    :key="String($store.state.instance.instanceUrl)"
    :class="[$store.state.ui.queueFocused ? 'queue-focused' : '',
             {'has-bottom-player': $store.state.queue.tracks.length > 0}]"
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
        v-if="$store.state.ui.queueFocused"
        @touch-progress="$refs.player.setCurrentTime($event)"
      />
    </transition>
    <router-view
      role="main"
      :class="{hidden: $store.state.ui.queueFocused}"
    />
    <player ref="player" />
    <playlist-modal v-if="$store.state.auth.authenticated" />
    <channel-upload-modal v-if="$store.state.auth.authenticated" />
    <filter-modal v-if="$store.state.auth.authenticated" />
    <report-modal />
    <shortcuts-modal
      :show="showShortcutsModal"
      @update:show="showShortcutsModal = $event"
    />
    <GlobalEvents @keydown.h.exact="showShortcutsModal = !showShortcutsModal" />
  </div>
</template>

<script>
import axios from 'axios'
import { uniq, get } from 'lodash-es'
import { mapState, mapGetters } from 'vuex'
import { useWebSocket, whenever } from '@vueuse/core'
import GlobalEvents from '@/components/utils/global-events.vue'
import locales from './locales'
import { getClientOnlyRadio } from '@/radios'

import Player from '@/components/audio/Player.vue'
import Queue from '@/components/Queue.vue'
import PlaylistModal from '@/components/playlists/PlaylistModal.vue'
import ChannelUploadModal from '@/components/channels/UploadModal.vue'
import Sidebar from '@/components/Sidebar.vue'
import ServiceMessages from '@/components/ServiceMessages.vue'
import SetInstanceModal from '@/components/SetInstanceModal.vue'
import ShortcutsModal from '@/components/ShortcutsModal.vue'
import FilterModal from '@/components/moderation/FilterModal.vue'
import ReportModal from '@/components/moderation/ReportModal.vue'
import { watch, watchEffect } from '@vue/composition-api'

export default {
  name: 'App',
  components: {
    Player,
    Queue,
    PlaylistModal,
    ChannelUploadModal,
    Sidebar,
    ServiceMessages,
    SetInstanceModal,
    ShortcutsModal,
    FilterModal,
    ReportModal,
    GlobalEvents
  },
  setup (props, { root }) {
    const store = root.$store

    const url = store.getters['instance/absoluteUrl']('api/v1/activity')
      .replace(/^http/, 'ws')

    const { data, status, open, close } = useWebSocket(url, {
      autoReconnect: true,
      immediate: false
    })

    watch(() => store.state.auth.authenticated, (authenticated) => {
      if (authenticated) return open()
      close()
    })

    whenever(data, () => {
      store.dispatch('ui/websocketEvent', JSON.parse(data.value))
    })

    watchEffect(() => {
      console.log('Websocket status:', status.value)
    })
  },
  data () {
    return {
      instanceUrl: null,
      showShortcutsModal: false,
      showSetInstanceModal: false,
      initialTitle: document.title,
      width: window.innerWidth
    }
  },
  computed: {
    ...mapState({
      messages: state => state.ui.messages,
      nodeinfo: state => state.instance.nodeinfo,
      playing: state => state.player.playing,
      bufferProgress: state => state.player.bufferProgress,
      isLoadingAudio: state => state.player.isLoadingAudio,
      serviceWorker: state => state.ui.serviceWorker
    }),
    ...mapGetters({
      hasNext: 'queue/hasNext',
      currentTrack: 'queue/currentTrack',
      progress: 'player/progress'
    }),
    labels () {
      const play = this.$pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Play track')
      const pause = this.$pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Pause track')
      const next = this.$pgettext('Sidebar/Player/Icon.Tooltip', 'Next track')
      const expandQueue = this.$pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Expand queue')
      return {
        play,
        pause,
        next,
        expandQueue
      }
    },
    suggestedInstances () {
      const instances = this.$store.state.instance.knownInstances.slice(0)
      if (this.$store.state.instance.frontSettings.defaultServerUrl) {
        let serverUrl = this.$store.state.instance.frontSettings.defaultServerUrl
        if (!serverUrl.endsWith('/')) {
          serverUrl = serverUrl + '/'
        }
        instances.push(serverUrl)
      }
      instances.push(this.$store.getters['instance/defaultUrl'](), 'https://demo.funkwhale.audio/')
      return uniq(instances.filter((e) => { return e }))
    },
    version () {
      if (!this.nodeinfo) {
        return null
      }
      return get(this.nodeinfo, 'software.version')
    },
    customStylesheets () {
      if (this.$store.state.instance.frontSettings) {
        return this.$store.state.instance.frontSettings.additionalStylesheets || []
      }
      return null
    },
    matchDarkColorScheme () {
      if (window.matchMedia) {
        return window.matchMedia('(prefers-color-scheme: dark)')
      }
      return null
    }
  },
  watch: {
    '$store.state.instance.instanceUrl' (v) {
      this.$store.dispatch('instance/fetchSettings')
      this.fetchNodeInfo()
    },
    '$store.state.ui.theme': {
      immediate: true,
      handler (newValue) {
        const matchesDark = this.matchDarkColorScheme
        if (matchesDark) {
          if (newValue === 'system') {
            newValue = matchesDark.matches ? 'dark' : 'light'
            matchesDark.addEventListener('change', this.handleThemeChange)
          } else {
            matchesDark.removeEventListener('change', this.handleThemeChange)
          }
        } else {
          if (newValue === 'system') {
            newValue = 'light'
          }
        }
        this.setTheme(newValue)
      }
    },
    '$store.state.ui.currentLanguage': {
      immediate: true,
      handler (newValue) {
        const self = this
        const htmlLocale = newValue.toLowerCase().replace('_', '-')
        document.documentElement.setAttribute('lang', htmlLocale)
        if (newValue === 'en_US') {
          self.$language.current = 'noop'
          self.$language.current = newValue
          return self.$store.commit('ui/momentLocale', 'en')
        }
      }
    },
    currentTrack: {
      immediate: true,
      handler (newValue) {
        this.updateDocumentTitle()
      }
    },
    '$store.state.ui.pageTitle': {
      immediate: true,
      handler (newValue) {
        this.updateDocumentTitle()
      }
    },
    'serviceWorker.updateAvailable': {
      handler (v) {
        if (!v) {
          return
        }
        const self = this
        this.$store.commit('ui/addMessage', {
          content: this.$pgettext('App/Message/Paragraph', 'A new version of the app is available.'),
          date: new Date(),
          key: 'refreshApp',
          displayTime: 0,
          classActions: 'bottom attached opaque',
          actions: [
            {
              text: this.$pgettext('App/Message/Paragraph', 'Update'),
              class: 'primary',
              click: function () {
                self.updateApp()
              }
            },
            {
              text: this.$pgettext('App/Message/Paragraph', 'Later'),
              class: 'basic'
            }
          ]
        })
      },
      immediate: true
    }
  },
  async created () {
    if (navigator.serviceWorker) {
      navigator.serviceWorker.addEventListener(
        'controllerchange', () => {
          if (this.serviceWorker.refreshing) return
          this.$store.commit('ui/serviceWorker', {
            refreshing: true
          })
          window.location.reload()
        }
      )
    }
    window.addEventListener('resize', this.handleResize)
    this.handleResize()
    const self = this
    if (!this.$store.state.ui.selectedLanguage) {
      this.autodetectLanguage()
    }
    setInterval(() => {
      // used to redraw ago dates every minute
      self.$store.commit('ui/computeLastDate')
    }, 1000 * 60)
    const urlParams = new URLSearchParams(window.location.search)
    const serverUrl = urlParams.get('_server')
    if (serverUrl) {
      this.$store.commit('instance/instanceUrl', serverUrl)
    }
    const url = urlParams.get('_url')
    if (url) {
      await this.$router.replace(url)
    } else if (!this.$store.state.instance.instanceUrl) {
      // we have several way to guess the API server url. By order of precedence:
      // 1. use the url provided in settings.json, if any
      // 2. use the url specified when building via VUE_APP_INSTANCE_URL
      // 3. use the current url
      const defaultInstanceUrl =
        this.$store.state.instance.frontSettings.defaultServerUrl ||
        import.meta.env.VUE_APP_INSTANCE_URL || this.$store.getters['instance/defaultUrl']()
      this.$store.commit('instance/instanceUrl', defaultInstanceUrl)
    } else {
      // needed to trigger initialization of axios / service worker
      this.$store.commit('instance/instanceUrl', this.$store.state.instance.instanceUrl)
    }
    await this.fetchNodeInfo()
    this.$store.dispatch('instance/fetchSettings')
    this.$store.commit('ui/addWebsocketEventHandler', {
      eventName: 'inbox.item_added',
      id: 'sidebarCount',
      handler: this.incrementNotificationCountInSidebar
    })
    this.$store.commit('ui/addWebsocketEventHandler', {
      eventName: 'mutation.created',
      id: 'sidebarReviewEditCount',
      handler: this.incrementReviewEditCountInSidebar
    })
    this.$store.commit('ui/addWebsocketEventHandler', {
      eventName: 'mutation.updated',
      id: 'sidebarReviewEditCount',
      handler: this.incrementReviewEditCountInSidebar
    })
    this.$store.commit('ui/addWebsocketEventHandler', {
      eventName: 'report.created',
      id: 'sidebarPendingReviewReportCount',
      handler: this.incrementPendingReviewReportsCountInSidebar
    })
    this.$store.commit('ui/addWebsocketEventHandler', {
      eventName: 'user_request.created',
      id: 'sidebarPendingReviewRequestCount',
      handler: this.incrementPendingReviewRequestsCountInSidebar
    })
    this.$store.commit('ui/addWebsocketEventHandler', {
      eventName: 'Listen',
      id: 'handleListen',
      handler: this.handleListen
    })
  },
  mounted () {
    const self = this
    // slight hack to allow use to have internal links in <translate> tags
    // while preserving router behaviour
    document.documentElement.addEventListener('click', function (event) {
      if (!event.target.matches('a.internal')) return
      self.$router.push(event.target.getAttribute('href'))
      event.preventDefault()
    }, false)
    this.$nextTick(() => {
      document.getElementById('fake-content').classList.add('loaded')
    })
  },
  destroyed () {
    this.$store.commit('ui/removeWebsocketEventHandler', {
      eventName: 'inbox.item_added',
      id: 'sidebarCount'
    })
    this.$store.commit('ui/removeWebsocketEventHandler', {
      eventName: 'mutation.created',
      id: 'sidebarReviewEditCount'
    })
    this.$store.commit('ui/removeWebsocketEventHandler', {
      eventName: 'mutation.updated',
      id: 'sidebarReviewEditCount'
    })
    this.$store.commit('ui/removeWebsocketEventHandler', {
      eventName: 'mutation.updated',
      id: 'sidebarPendingReviewReportCount'
    })
    this.$store.commit('ui/removeWebsocketEventHandler', {
      eventName: 'user_request.created',
      id: 'sidebarPendingReviewRequestCount'
    })
    this.$store.commit('ui/removeWebsocketEventHandler', {
      eventName: 'Listen',
      id: 'handleListen'
    })
  },
  methods: {
    incrementNotificationCountInSidebar (event) {
      this.$store.commit('ui/incrementNotifications', { type: 'inbox', count: 1 })
    },
    incrementReviewEditCountInSidebar (event) {
      this.$store.commit('ui/incrementNotifications', { type: 'pendingReviewEdits', value: event.pending_review_count })
    },
    incrementPendingReviewReportsCountInSidebar (event) {
      this.$store.commit('ui/incrementNotifications', { type: 'pendingReviewReports', value: event.unresolved_count })
    },
    incrementPendingReviewRequestsCountInSidebar (event) {
      this.$store.commit('ui/incrementNotifications', { type: 'pendingReviewRequests', value: event.pending_count })
    },
    handleListen (event) {
      if (this.$store.state.radios.current && this.$store.state.radios.running) {
        const current = this.$store.state.radios.current
        if (current.clientOnly && current.type === 'account') {
          getClientOnlyRadio(current).handleListen(current, event, this.$store)
        }
      }
    },
    async fetchNodeInfo () {
      const response = await axios.get('instance/nodeinfo/2.0/')
      this.$store.commit('instance/nodeinfo', response.data)
    },
    autodetectLanguage () {
      const userLanguage = navigator.language || navigator.userLanguage
      const available = locales.locales.map(e => { return e.code })
      let candidate
      const matching = available.filter((a) => {
        return userLanguage.replace('-', '_') === a
      })
      const almostMatching = available.filter((a) => {
        return userLanguage.replace('-', '_').split('_')[0] === a.split('_')[0]
      })
      if (matching.length > 0) {
        candidate = matching[0]
      } else if (almostMatching.length > 0) {
        candidate = almostMatching[0]
      } else {
        return
      }
      this.$store.commit('ui/currentLanguage', candidate)
    },
    getTrackInformationText (track) {
      const trackTitle = track.title
      const albumArtist = (track.album) ? track.album.artist.name : null
      const artistName = (
        (track.artist) ? track.artist.name : albumArtist)
      const text = `♫ ${trackTitle} – ${artistName} ♫`
      return text
    },
    updateDocumentTitle () {
      const parts = []
      const currentTrackPart = (
        (this.currentTrack)
          ? this.getTrackInformationText(this.currentTrack)
          : null)
      if (currentTrackPart) {
        parts.push(currentTrackPart)
      }
      if (this.$store.state.ui.pageTitle) {
        parts.push(this.$store.state.ui.pageTitle)
      }
      parts.push(this.initialTitle || 'Funkwhale')
      document.title = parts.join(' – ')
    },

    updateApp () {
      this.$store.commit('ui/serviceWorker', { updateAvailable: false })
      if (!this.serviceWorker.registration || !this.serviceWorker.registration.waiting) { return }
      this.serviceWorker.registration.waiting.postMessage({ command: 'skipWaiting' })
    },
    handleResize () {
      this.width = window.innerWidth
    },
    handleThemeChange (event) {
      this.setTheme(event.matches ? 'dark' : 'light')
    },
    setTheme (theme) {
      const oldTheme = (theme === 'light') ? 'dark' : 'light'
      document.body.classList.remove(`theme-${oldTheme}`)
      document.body.classList.add(`theme-${theme}`)
    }
  }
}
</script>

<style lang="scss">
@import "style/_main";

</style>
