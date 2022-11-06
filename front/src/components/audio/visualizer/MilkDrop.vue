<script setup lang="ts">
import { useMilkDrop } from '~/composables/audio/visualizer'

import { onScopeDispose, ref, watch } from 'vue'
import { useRafFn } from '@vueuse/core'

const milkdrop = ref()
const canvas = ref()

const { visualizer, loadRandomPreset, render, isVisible } = useMilkDrop(canvas)

const { resume, pause } = useRafFn(render)

watch(isVisible, (visible) => visible
  ? resume()
  : pause()
)

onScopeDispose(() => {
  pause()
  if (visualizer.value) {
    visualizer.value.loseGLContext()
  }
})

defineExpose({
  loadRandomPreset
})
</script>

<template>
  <div
    ref="milkdrop"
    class="visualizer"
  >
    <canvas
      ref="canvas"
      @click="loadRandomPreset()"
    />
  </div>
</template>
