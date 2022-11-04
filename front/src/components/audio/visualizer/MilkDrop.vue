<script setup lang="ts">
import { useMilkDrop } from '~/composables/audio/visualizer'

import { onScopeDispose, ref } from 'vue'
import { useRafFn } from '@vueuse/core'

const milkdrop = ref()
const canvas = ref()

const { visualizer, loadRandomPreset, render } = useMilkDrop(canvas)

const { pause } = useRafFn(render)

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
