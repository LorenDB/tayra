<script setup lang="ts">
import type { QueueTrack } from '~/composables/audio/queue'
import type { Track } from '~/types'

import { useI18n } from 'vue-i18n'
import { computed } from 'vue'

interface Props {
  track?: Track | QueueTrack
  button?: boolean
  border?: boolean
}

withDefaults(defineProps<Props>(), {
  track: undefined,
  button: false,
  border: false
})

const { t } = useI18n()

const labels = computed(() => ({
  addToPlaylist: t('components.playlists.TrackPlaylistIcon.button.add')
}))
</script>

<template>
  <button
    v-if="button"
    :class="['ui', 'icon', 'labeled', 'button']"
    @click.stop="$store.commit('playlists/chooseTrack', track)"
  >
    <i class="list icon" />
    {{ $t('components.playlists.TrackPlaylistIcon.button.add') }}
  </button>
  <button
    v-else
    :class="['ui', 'basic', 'circular', 'icon', {'really': !border}, 'button']"
    :aria-label="labels.addToPlaylist"
    :title="labels.addToPlaylist"
    @click.stop="$store.commit('playlists/chooseTrack', track)"
  >
    <i :class="['list', 'basic', 'icon']" />
  </button>
</template>
