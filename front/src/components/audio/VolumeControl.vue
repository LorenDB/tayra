<script setup lang="ts">
import { ref, computed } from 'vue'
import { useStore } from '~/store'
import { useGettext } from 'vue3-gettext'
import { useTimeoutFn } from '@vueuse/core'
import usePlayer from '~/composables/audio/usePlayer'

const store = useStore()
const { volume, mute, unmute } = usePlayer()

const expanded = ref(false)
const volumeSteps = 100

const sliderVolume = computed({
  get: () => volume.value * volumeSteps,
  set: (value) => store.commit('player/volume', value / volumeSteps)
})

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
      v-if="sliderVolume === 0"
      role="button"
      :title="labels.unmute"
      :aria-label="labels.unmute"
      @click.prevent.stop="unmute"
    >
      <i class="volume off icon" />
    </span>
    <span
      v-else-if="sliderVolume < 0.5"
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
        v-model="sliderVolume"
        type="range"
        step="any"
        min="0"
        :max="volumeSteps"
      >
    </div>
  </button>
</template>
