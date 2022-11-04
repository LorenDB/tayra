import type { Ref } from 'vue'

import { AUDIO_CONTEXT, GAIN_NODE } from './audio-api'
import { useResizeObserver } from '@vueuse/core'
import { ref, markRaw } from 'vue'

// @ts-expect-error butterchurn has no typings
import butterchurnPresets from 'butterchurn-presets'

// @ts-expect-error butterchurn has no typings
import butterchurn from 'butterchurn'

export const useMilkDrop = (canvas: Ref<HTMLCanvasElement>) => {
  const presets = Object.entries(butterchurnPresets)
  const visualizer = ref()

  const loadRandomPreset = (blendTime = 1) => {
    const index = (presets.length * Math.random()) | 0
    const [name, preset] = presets[index]
    console.log(`Switching to preset: '${name}'`)
    visualizer.value.loadPreset(preset, blendTime)
  }

  const initialize = (canvas: HTMLCanvasElement, width: number, height: number) => {
    visualizer.value = markRaw(butterchurn.createVisualizer(AUDIO_CONTEXT, canvas, {
      width,
      height
    }))

    loadRandomPreset(0)
    visualizer.value.connectAudio(GAIN_NODE)
    visualizer.value.setInternalMeshSize(128, 96)
  }

  useResizeObserver(canvas, ([entry]) => {
    const { width, height } = entry.contentRect

    console.log(width, height)
    canvas.value.width = width
    canvas.value.height = height

    if (visualizer.value === undefined) {
      initialize(entry.target as HTMLCanvasElement, width, height)
      return
    }

    visualizer.value.setRendererSize(width, height)
  })

  const render = () => {
    try {
      visualizer.value?.render()
    } catch (error) {
      console.error(error)
      loadRandomPreset(0)
    }
  }

  return {
    visualizer,
    loadRandomPreset,
    render
  }
}
