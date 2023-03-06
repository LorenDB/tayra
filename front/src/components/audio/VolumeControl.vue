<script setup lang="ts">
import { usePlayer } from '~/composables/audio/player'
import { useTimeoutFn } from '@vueuse/core'
import { ref, computed } from 'vue'
import { useI18n } from 'vue-i18n'

const { volume, mute } = usePlayer()
const expanded = ref(false)

const { t } = useI18n()
const labels = computed(() => ({
  unmute: t('components.audio.VolumeControl.button.unmute'),
  mute: t('components.audio.VolumeControl.button.mute'),
  slider: t('components.audio.VolumeControl.label.slider')
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

const scroll = (event: WheelEvent) => {
  volume.value += -Math.sign(event.deltaY) * 0.05
}
</script>

<template>
  <button
    class="circular control button"
    :class="['component-volume-control', {'expanded': expanded}]"
    @click.prevent.stop=""
    @mouseover="handleOver"
    @mouseleave="handleLeave"
    @wheel.stop.prevent="scroll"
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
