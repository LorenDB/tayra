<script setup lang="ts">
import { useMilkDrop } from '~/composables/audio/visualizer'

import { onScopeDispose, ref } from 'vue'
import { refAutoReset, useFullscreen, useIdle, useRafFn, whenever } from '@vueuse/core'
import { useQueue } from '~/composables/audio/queue'

const milkdrop = ref()
const canvas = ref()

const { isFullscreen: fullscreen, enter, exit } = useFullscreen(milkdrop)
const { visualizer, loadRandomPreset, render } = useMilkDrop(canvas)
const { currentTrack } = useQueue()
const { idle } = useIdle(2000)

const showTrackInfo = refAutoReset(false, 5000)
whenever(currentTrack, () => (showTrackInfo.value = true))

const { pause } = useRafFn(render)

onScopeDispose(() => {
  exit()
  pause()
  if (visualizer.value) {
    visualizer.value.loseGLContext()
  }
})
</script>

<template>
  <div
    ref="milkdrop"
    :class="['visualizer', { idle, fullscreen }]"
  >
    <canvas
      ref="canvas"
      @click="loadRandomPreset()"
    />

    <Teleport to=".cover > .cover-buttons">
      <button
        v-if="!fullscreen"
        class="ui secondary button"
        @click="enter"
      >
        <i class="icon expand arrows alternate" />
      </button>
    </Teleport>

    <Transition name="slide-down">
      <div
        v-if="fullscreen && (!idle || showTrackInfo)"
        class="track-info"
        @click="loadRandomPreset()"
      >
        <h1>{{ currentTrack.title }}</h1>
        <h2>{{ currentTrack.artistName }} &mdash; {{ currentTrack.albumTitle }}</h2>
      </div>
    </Transition>
  </div>
</template>

<style scoped lang="scss">
.visualizer {
  &.idle {
    cursor: none;
  }

  &.fullscreen {
    .slide-down-enter-active,
    .slide-down-leave-active {
      transition: all 0.2s ease;
      will-change: transform, opacity;
    }

    .slide-down-enter-from,
    .slide-down-leave-to {
      opacity: 0;
      transform: translateY(5vh);
    }
  }

}

.track-info {
  position: absolute;
  z-index: 2;
  bottom: 0;
  left: 0;
  width: 100%;
  background: linear-gradient(to bottom, #0000, #000);
  color: #fff;
  text-align: left;
  padding: 3em 1em 1em;

  h1, h2 {
    margin: 0;
  }
}

</style>
