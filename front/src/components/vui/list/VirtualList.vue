<script setup lang="ts">
import type { MaybeElementRef, MaybeElement } from '@vueuse/core'

import { useMouse, useCurrentElement, useResizeObserver, useRafFn, useElementByPoint } from '@vueuse/core'
import { ref, watchEffect, reactive } from 'vue'

import VirtualItem from './VirtualItem.vue'
// @ts-expect-error no typings
import VirtualList from 'vue3-virtual-scroll-list'

interface Emits {
  (e: 'reorder', from: number, to: number): void
}

interface Props {
  list: object[]
  size: number
  dataKey: string
}

const emit = defineEmits<Emits>()
const props = defineProps<Props>()

const ghostContainer = ref()
const hoveredIndex = ref()
const draggedItem = ref()
const position = ref('after')

const getIndex = (element: HTMLElement) => +(element?.getAttribute('data-index') ?? 0)

const isTouch = ref(false)
const onMousedown = (event: MouseEvent | TouchEvent) => {
  const element = event.target as HTMLElement
  const dragItem = element.closest('.drag-item')?.children[0] as HTMLElement
  if (!dragItem || !element.classList.contains('handle')) return

  // Touch devices stop emitting touch events while container is scrolled
  // NOTE: FF does not support TouchEvent constructor
  isTouch.value = window.TouchEvent
    ? event instanceof TouchEvent
    : !(event instanceof MouseEvent)

  const ghost = dragItem.cloneNode(true) as HTMLElement
  ghost.classList.add('drag-ghost')
  ghostContainer.value.appendChild(ghost)

  const index = getIndex(dragItem)
  document.body.classList.add('dragging')
  hoveredIndex.value = index
  draggedItem.value = {
    item: props.list[index],
    ghost,
    index
  }

  resume()
}

// Touch and mobile devices support
const onTouchmove = (event: TouchEvent) => {
  if (draggedItem.value) {
    event.preventDefault()
  }
}

document.addEventListener('touchcancel', (event: TouchEvent) => {
  cleanup()
})

const reorder = (event: MouseEvent | TouchEvent) => {
  const element = event.target as HTMLElement
  const dragItem = element.closest('.drag-item')?.children[0]

  if (dragItem && draggedItem.value) {
    const from = draggedItem.value.index
    let to = hoveredIndex.value

    if (from === to) return cleanup()
    to -= +(position.value === 'before')
    to += +(from > to)

    if (from === to) return cleanup()
    emit('reorder', from, to)
  }

  cleanup()
}

document.addEventListener('mouseup', reorder)
document.addEventListener('touchend', reorder)

const cleanup = () => {
  pause()
  document.body.classList.remove('dragging')
  draggedItem.value?.ghost?.remove()
  draggedItem.value = undefined
  hoveredIndex.value = undefined
  scrollDirection.value = undefined
}

const dragClassHandler = (index: number) => draggedItem.value && hoveredIndex.value === index
  ? `drop-${position.value}`
  : ''

const scrollDirection = ref()
const containerSize = reactive({ bottom: 0, top: 0 })
const { x, y: screenY } = useMouse({ type: 'client' })
const { element: hoveredElement } = useElementByPoint({ x, y: screenY })

// Find current index and position on both desktop and mobile devices
watchEffect(() => {
  const dragItem = (hoveredElement.value as HTMLElement)?.closest('.drag-item')?.children[0] as HTMLElement
  if (!dragItem) return

  hoveredIndex.value = getIndex(dragItem)
  const { y } = dragItem.getBoundingClientRect()
  position.value = screenY.value - y < props.size / 2 ? 'before' : 'after'
})

// Automatically scroll when on the edge
watchEffect(() => {
  const { top, bottom } = containerSize
  const y = Math.min(bottom, Math.max(top, screenY.value))

  if (draggedItem.value) {
    ghostContainer.value.style.top = `${y}px`

    scrollDirection.value = y === top
      ? 'up'
      : y === bottom
        ? 'down'
        : undefined

    return
  }

  scrollDirection.value = undefined
})

const keeps = ref(30)
const el = useCurrentElement()
useResizeObserver(el as unknown as MaybeElementRef<MaybeElement>, ([entry]) => {
  const height = entry.borderBoxSize?.[0]?.blockSize ?? 0

  if (height !== 0) {
    containerSize.top = (entry.target as HTMLElement).offsetTop
    containerSize.bottom = height + containerSize.top
    keeps.value = (containerSize.bottom - containerSize.top) / props.size * 2 | 0
  }
})

let lastDate = +new Date()
const { resume, pause } = useRafFn(() => {
  const now = +new Date()
  const delta = now - lastDate
  const direction = scrollDirection.value

  if (direction && el.value?.children[0] && !isTouch.value) {
    el.value.children[0].scrollTop += 200 / delta * (direction === 'up' ? -1 : 1)
  }

  lastDate = now
}, { immediate: false })

const virtualList = ref()
defineExpose({
  scrollToIndex: (index: number) => virtualList.value?.scrollToIndex(index),
  cleanup
})
</script>

<script lang="ts">
export default {
  inheritAttrs: false
}
</script>

<template>
  <div>
    <component
      :is="VirtualList"
      ref="virtualList"
      class="virtual-list"
      wrap-class="drag-container"
      item-class="drag-item"
      :keeps="keeps"
      :data-key="dataKey"
      :data-sources="list"
      :data-component="VirtualItem"
      :estimate-size="size"
      :extra-props="{
        dragClassHandler,
        ...$attrs
      }"
      @mousedown="onMousedown"
      @touchstart="onMousedown"
      @touchmove="onTouchmove"
    />

    <div
      ref="ghostContainer"
      class="ghost-container"
    />
  </div>
</template>

<style>
.drag-container {
  position: relative;
}

.dragging {
  user-select: none;
  cursor: grab !important;
}

.drop-before {
  box-shadow: 0 -1px 0 var(--vibrant-color),
        inset 0  1px 0 var(--vibrant-color);
}

.drop-after {
  box-shadow: 0  1px 0 var(--vibrant-color),
        inset 0 -1px 0 var(--vibrant-color);
}

.drag-ghost {
  background: transparent !important;
}

.ghost-container {
  position: absolute;
  pointer-events: none;
  z-index: 1002;
  width: 100%;
  transform: translateY(-50%);
  left: 0;
  top: 0;
  opacity: 0.8;
  background: rgba(255, 255, 255, 0.1);
}

.theme-light .ghost-container {
  background: rgba(0, 0, 0, 0.1);
}
</style>
