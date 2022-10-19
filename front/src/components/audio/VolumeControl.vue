<script setup lang="ts">
import { volume, mute } from '~/composables/audio/player'
import { useTimeoutFn } from '@vueuse/core'
import { useGettext } from 'vue3-gettext'
import { ref, computed } from 'vue'

const expanded = ref(false)

const { $pgettext } = useGettext()
const labels = computed(() => ({
  unmute: $pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Unmute'),
  mute: $pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Mute'),
  slider: $pgettext('Sidebar/Player/Icon.Tooltip/Verb', 'Adjust volume')
}))

const { start, stop } = useTimeoutFn(() => (expanded.value = false), 500, { immediate: false })

const handleOver = () => {
  stop()
  expanded.value = true
}

const handleLeave = () => {
  stop()
  start()
}
</script>

<template>
  <button
    class="circular control button"
    :class="['component-volume-control', {'expanded': expanded}]"
    @click.prevent.stop=""
    @mouseover="handleOver"
    @mouseleave="handleLeave"
  >
    <span
      v-if="volume === 0"
      role="button"
      :title="labels.unmute"
      :aria-label="labels.unmute"
      @click.prevent.stop="mute"
    >
      <i class="volume off icon" />
    </span>
    <span
      v-else-if="volume < 0.5"
      role="button"
      :title="labels.mute"
      :aria-label="labels.mute"
      @click.prevent.stop="mute"
    >
      <i class="volume down icon" />
    </span>
    <span
      v-else
      role="button"
      :title="labels.mute"
      :aria-label="labels.mute"
      @click.prevent.stop="mute"
    >
      <i class="volume up icon" />
    </span>
    <div class="popup">
      <label
        for="volume-slider"
        class="visually-hidden"
      >{{ labels.slider }}</label>
      <input
        id="volume-slider"
        v-model="volume"
        type="range"
        step="any"
        min="0"
        max="1"
      >
    </div>
  </button>
</template>
