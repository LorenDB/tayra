<script setup lang="ts">
import { useGettext } from 'vue3-gettext'
import { computed } from 'vue'

import { isPlaying } from '~/composables/audio/player'
import {
  hasPrevious,
  playPrevious,
  hasNext,
  playNext,
  currentTrack
} from '~/composables/audio/queue'

const { $pgettext } = useGettext()
const labels = computed(() => ({
  previous: $pgettext('Sidebar/Player/Icon.Tooltip', 'Previous track'),
  play: $pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Play'),
  pause: $pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Pause'),
  next: $pgettext('Sidebar/Player/Icon.Tooltip', 'Next track')
}))
</script>

<template>
  <div class="player-controls">
    <button
      :title="labels.previous"
      :aria-label="labels.previous"
      :disabled="!hasPrevious"
      class="circular button control tablet-and-up"
      @click.prevent.stop="playPrevious()"
    >
      <i :class="['ui', 'large', {'disabled': !hasPrevious}, 'backward step', 'icon']" />
    </button>
    <button
      v-if="!isPlaying"
      :title="labels.play"
      :aria-label="labels.play"
      class="circular button control"
      @click.prevent.stop="isPlaying = true"
    >
      <i :class="['ui', 'big', 'play', {'disabled': !currentTrack}, 'icon']" />
    </button>
    <button
      v-else
      :title="labels.pause"
      :aria-label="labels.pause"
      class="circular button control"
      @click.prevent.stop="isPlaying = false"
    >
      <i :class="['ui', 'big', 'pause', {'disabled': !currentTrack}, 'icon']" />
    </button>
    <button
      :title="labels.next"
      :aria-label="labels.next"
      :disabled="!hasNext"
      class="circular button control"
      @click.prevent.stop="playNext()"
    >
      <i :class="['ui', 'large', {'disabled': !hasNext}, 'forward step', 'icon']" />
    </button>
  </div>
</template>
