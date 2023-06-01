<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { computed } from 'vue'

import { usePlayer } from '~/composables/audio/player'
import { useQueue } from '~/composables/audio/queue'

const { playPrevious, hasNext, playNext, currentTrack } = useQueue()
const { isPlaying } = usePlayer()

const { t } = useI18n()
const labels = computed(() => ({
  previous: t('components.audio.PlayerControls.labels.previous'),
  play: t('components.audio.PlayerControls.labels.play'),
  pause: t('components.audio.PlayerControls.labels.pause'),
  next: t('components.audio.PlayerControls.labels.next')
}))
</script>

<template>
  <div class="player-controls">
    <button
      :title="labels.previous"
      :aria-label="labels.previous"
      class="circular button control tablet-and-up"
      @click.prevent.stop="playPrevious()"
    >
      <i :class="['ui', 'large', 'backward step', 'icon']" />
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
