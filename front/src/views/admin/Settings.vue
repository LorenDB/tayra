<script setup lang="ts">
import type { SettingsGroup as SettingsGroupType } from '~/types'

import axios from 'axios'
import $ from 'jquery'

import SettingsGroup from '~/components/admin/SettingsGroup.vue'

import { useCurrentElement } from '@vueuse/core'
import { ref, nextTick, onMounted, computed, watch } from 'vue'
import { useRoute } from 'vue-router'
import { useGettext } from 'vue3-gettext'

const current = ref()
const settingsData = ref()

const { $pgettext } = useGettext()

const groups = computed(() => [
  {
    label: $pgettext('Content/Admin/Menu', 'Instance information'),
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
    label: $pgettext('*/*/*/Noun', 'Sign-ups'),
    id: 'signup',
    settings: [
      { name: 'users__registration_enabled' },
      { name: 'moderation__signup_approval_enabled' },
      { name: 'moderation__signup_form_customization', fieldType: 'formBuilder' }
    ]
  },
  {
    label: $pgettext('*/*/*/Noun', 'Security'),
    id: 'security',
    settings: [
      { name: 'common__api_authentication_required' },
      { name: 'users__default_permissions' },
      { name: 'users__upload_quota' }
    ]
  },
  {
    label: $pgettext('*/*/*/Noun', 'Music'),
    id: 'music',
    settings: [
      { name: 'music__transcoding_enabled' },
      { name: 'music__transcoding_cache_duration' }
    ]
  },
  {
    label: $pgettext('*/*/*', 'Channels'),
    id: 'channels',
    settings: [
      { name: 'audio__channels_enabled' },
      { name: 'audio__max_channels' }
    ]
  },
  {
    label: $pgettext('*/*/*', 'Playlists'),
    id: 'playlists',
    settings: [
      { name: 'playlists__max_tracks' }
    ]
  },
  {
    label: $pgettext('*/Moderation/*', 'Moderation'),
    id: 'moderation',
    settings: [
      { name: 'moderation__allow_list_enabled' },
      { name: 'moderation__allow_list_public' },
      { name: 'moderation__unauthenticated_report_types' }
    ]
  },
  {
    label: $pgettext('*/*/*', 'Federation'),
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
    label: $pgettext('Content/Admin/Menu', 'Subsonic'),
    id: 'subsonic',
    settings: [
      { name: 'subsonic__enabled' }
    ]
  },
  {
    label: $pgettext('Content/Home/Header', 'Statistics'),
    id: 'ui',
    settings: [
      { name: 'ui__custom_css' },
      { name: 'instance__funkwhale_support_message_enabled' }
    ]
  },
  {
    label: $pgettext('Content/Admin/Menu', 'User Interface'),
    id: 'statistics',
    settings: [
      { name: 'instance__nodeinfo_stats_enabled' },
      { name: 'instance__nodeinfo_private' }
    ]
  }
] as SettingsGroupType[])

const labels = computed(() => ({
  settings: $pgettext('Head/Admin/Title', 'Instance settings')
}))

const scrollTo = (id: string) => {
  current.value = id
  document.getElementById(id)?.scrollIntoView()
}

const route = useRoute()
if (route.hash) {
  scrollTo(route.hash.slice(1))
}

const el = useCurrentElement()
onMounted(async () => {
  await nextTick()
  $(el.value).find('select.dropdown').dropdown()
})

watch(settingsData, async () => {
  await nextTick()
  $(el.value).find('.sticky').sticky({ context: '#settings-grid' })
})

const isLoading = ref(false)
const fetchSettings = async () => {
  isLoading.value = true

  try {
    const response = await axios.get('instance/admin/settings/')
    settingsData.value = response.data
  } catch (error) {
    // TODO (wvffle): Handle error
  }

  isLoading.value = false
}

await fetchSettings()
await nextTick()
</script>

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
              :key="group.id"
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
