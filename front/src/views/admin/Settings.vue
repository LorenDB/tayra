<template>
  <main
    v-title="labels.settings"
    class="main pusher"
  >
    <div class="ui vertical stripe segment">
      <div class="ui text container">
        <div :class="['ui', {'loading': isLoading}, 'form']" />
        <div
          v-if="settingsData"
          id="settings-grid"
          class="ui grid"
        >
          <div class="twelve wide stretched column">
            <settings-group
              v-for="group in groups"
              :key="group.title"
              :settings-data="settingsData"
              :group="group"
            />
          </div>
          <div class="four wide column">
            <div class="ui sticky vertical secondary menu">
              <div class="header item">
                <translate translate-context="Content/Admin/Menu.Title">
                  Sections
                </translate>
              </div>
              <a
                v-for="(group, key) in groups"
                :key="key"
                :class="['menu', {active: group.id === current}, 'item']"
                :href="'#' + group.id"
                @click.prevent="scrollTo(group.id)"
              >{{ group.label }}</a>
            </div>
          </div>
        </div>
      </div>
    </div>
  </main>
</template>

<script>
import axios from 'axios'
import $ from 'jquery'

import SettingsGroup from '~/components/admin/SettingsGroup.vue'

export default {
  components: {
    SettingsGroup
  },
  data () {
    return {
      isLoading: false,
      settingsData: null,
      current: null
    }
  },
  computed: {
    labels () {
      return {
        settings: this.$pgettext('Head/Admin/Title', 'Instance settings')
      }
    },
    groups () {
      // somehow, extraction fails if in the return block directly
      const instanceLabel = this.$pgettext('Content/Admin/Menu', 'Instance information')
      const signupsLabel = this.$pgettext('*/*/*/Noun', 'Sign-ups')
      const securityLabel = this.$pgettext('*/*/*/Noun', 'Security')
      const musicLabel = this.$pgettext('*/*/*/Noun', 'Music')
      const channelsLabel = this.$pgettext('*/*/*', 'Channels')
      const playlistsLabel = this.$pgettext('*/*/*', 'Playlists')
      const federationLabel = this.$pgettext('*/*/*', 'Federation')
      const moderationLabel = this.$pgettext('*/Moderation/*', 'Moderation')
      const subsonicLabel = this.$pgettext('Content/Admin/Menu', 'Subsonic')
      const statisticsLabel = this.$pgettext('Content/Home/Header', 'Statistics')
      const uiLabel = this.$pgettext('Content/Admin/Menu', 'User Interface')
      return [
        {
          label: instanceLabel,
          id: 'instance',
          settings: [
            { name: 'instance__name' },
            { name: 'instance__short_description' },
            { name: 'instance__long_description', fieldType: 'markdown', fieldParams: { charLimit: null, permissive: true } },
            { name: 'instance__contact_email' },
            { name: 'instance__rules', fieldType: 'markdown', fieldParams: { charLimit: null, permissive: true } },
            { name: 'instance__terms', fieldType: 'markdown', fieldParams: { charLimit: null, permissive: true } },
            { name: 'instance__banner' },
            { name: 'instance__support_message', fieldType: 'markdown', fieldParams: { charLimit: null, permissive: true } }
          ]
        },
        {
          label: signupsLabel,
          id: 'signup',
          settings: [
            { name: 'users__registration_enabled' },
            { name: 'moderation__signup_approval_enabled' },
            { name: 'moderation__signup_form_customization', fieldType: 'formBuilder' }
          ]
        },
        {
          label: securityLabel,
          id: 'security',
          settings: [
            { name: 'common__api_authentication_required' },
            { name: 'users__default_permissions' },
            { name: 'users__upload_quota' }
          ]
        },
        {
          label: musicLabel,
          id: 'music',
          settings: [
            { name: 'music__transcoding_enabled' },
            { name: 'music__transcoding_cache_duration' }
          ]
        },
        {
          label: channelsLabel,
          id: 'channels',
          settings: [
            { name: 'audio__channels_enabled' },
            { name: 'audio__max_channels' }
          ]
        },
        {
          label: playlistsLabel,
          id: 'playlists',
          settings: [
            { name: 'playlists__max_tracks' }
          ]
        },
        {
          label: moderationLabel,
          id: 'moderation',
          settings: [
            { name: 'moderation__allow_list_enabled' },
            { name: 'moderation__allow_list_public' },
            { name: 'moderation__unauthenticated_report_types' }
          ]
        },
        {
          label: federationLabel,
          id: 'federation',
          settings: [
            { name: 'federation__enabled' },
            { name: 'federation__public_index' },
            { name: 'federation__collection_page_size' },
            { name: 'federation__music_cache_duration' },
            { name: 'federation__actor_fetch_delay' }
          ]
        },
        {
          label: subsonicLabel,
          id: 'subsonic',
          settings: [
            { name: 'subsonic__enabled' }
          ]
        },
        {
          label: uiLabel,
          id: 'ui',
          settings: [
            { name: 'ui__custom_css' },
            { name: 'instance__funkwhale_support_message_enabled' }
          ]
        },
        {
          label: statisticsLabel,
          id: 'statistics',
          settings: [
            { name: 'instance__nodeinfo_stats_enabled' },
            { name: 'instance__nodeinfo_private' }
          ]
        }
      ]
    }
  },
  watch: {
    settingsData () {
      const self = this
      this.$nextTick(() => {
        $(self.$el)
          .find('.sticky')
          .sticky({ context: '#settings-grid' })
      })
    }
  },
  created () {
    const self = this
    this.fetchSettings().then(r => {
      self.$nextTick(() => {
        if (self.$store.state.route.hash) {
          self.scrollTo(self.$store.state.route.hash.substr(1))
        }
        $('select.dropdown').dropdown()
      })
    })
  },
  methods: {
    scrollTo (id) {
      this.current = id
      document.getElementById(id).scrollIntoView()
    },
    fetchSettings () {
      const self = this
      self.isLoading = true
      return axios.get('instance/admin/settings/').then(response => {
        self.settingsData = response.data
        self.isLoading = false
      })
    }
  }
}
</script>
