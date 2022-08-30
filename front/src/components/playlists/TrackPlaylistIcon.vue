<script setup lang="ts">
import type { Track } from '~/types'

import { useGettext } from 'vue3-gettext'
import { computed } from 'vue'

interface Props {
  track?: Track | null
  button?: boolean
  border?: boolean
}

withDefaults(defineProps<Props>(), {
  track: null,
  button: false,
  border: false
})

const { $pgettext } = useGettext()

const labels = computed(() => ({
  addToPlaylist: $pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Add to playlist…')
}))
</script>

<template>
  <button
    v-if="button"
    :class="['ui', 'icon', 'labeled', 'button']"
    @click.stop="$store.commit('playlists/chooseTrack', track)"
  >
    <i class="list icon" />
    <translate translate-context="Sidebar/Player/Icon.Tooltip/Verb">
      Add to playlist…
    </translate>
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
