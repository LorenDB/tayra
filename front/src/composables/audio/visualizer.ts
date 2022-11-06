import type { Ref } from 'vue'

import { AUDIO_CONTEXT, GAIN_NODE } from './audio-api'
import { useResizeObserver, useStorage } from '@vueuse/core'
import { watchEffect, ref, markRaw } from 'vue'

// @ts-expect-error butterchurn has no typings
import butterchurnPresets from 'butterchurn-presets'

// @ts-expect-error butterchurn has no typings
import butterchurn from 'butterchurn'

export const useMilkDrop = (canvas: Ref<HTMLCanvasElement>) => {
  const presets = Object.keys(butterchurnPresets)
  const visualizer = ref()

  const getRandomPreset = () => {
    const index = (presets.length * Math.random()) | 0
    return presets[index]
  }

  const presetName = useStorage<string | undefined>('milk-drop:preset', undefined)
  watchEffect(() => {
    const name = presetName.value
    if (name === undefined) return

    console.log(`Switching to preset: '${name}'`)
    visualizer.value?.loadPreset(butterchurnPresets[name], 1)
  })

  const loadRandomPreset = () => {
    const name = getRandomPreset()
    presetName.value = name
  }

  const initialize = (canvas: HTMLCanvasElement, width: number, height: number) => {
    visualizer.value = markRaw(butterchurn.createVisualizer(AUDIO_CONTEXT, canvas, {
      width,
      height
    }))

    if (presetName.value === undefined) {
      presetName.value = getRandomPreset()
    }

    visualizer.value.connectAudio(GAIN_NODE)
    visualizer.value.setInternalMeshSize(128, 96)
  }

  const isVisible = ref(false)
  useResizeObserver(canvas, ([entry]) => {
    const { width, height } = entry.contentRect

    canvas.value.width = width
    canvas.value.height = height
    isVisible.value = !!(width * height)

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
      loadRandomPreset()
    }
  }

  return {
    visualizer,
    loadRandomPreset,
    render,
    isVisible
  }
}
