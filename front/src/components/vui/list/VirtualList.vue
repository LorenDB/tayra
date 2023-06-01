<script setup lang="ts">
import { useMouse, useCurrentElement, useRafFn, useElementByPoint } from '@vueuse/core'
import { ref, watchEffect, reactive, watch } from 'vue'

// @ts-expect-error no typings
import { RecycleScroller } from 'vue-virtual-scroller'
import 'vue-virtual-scroller/dist/vue-virtual-scroller.css'

interface Events {
  (e: 'reorder', from: number, to: number): void
  (e: 'visible'): void
}

interface Props {
  list: object[]
  size: number
}

const emit = defineEmits<Events>()
const props = defineProps<Props>()

const ghostContainer = ref()
const hoveredIndex = ref()
const draggedItem = ref()
const position = ref('after')

const getIndex = (element: HTMLElement) => +(element?.getAttribute('data-index') ?? 0)

const isTouch = ref(false)
const onMousedown = (event: MouseEvent | TouchEvent) => {
  const element = event.target as HTMLElement
  const dragItem = element.closest('.drag-item') as HTMLElement
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
  if (draggedItem.value) {
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

const scrollDirection = ref()
const containerSize = reactive({ bottom: 0, top: 0 })
const { x, y: screenY } = useMouse({ type: 'client' })

const { element: hoveredElement, pause: dragTrackPause, resume: dragTrackStart } = useElementByPoint({ x, y: screenY })
dragTrackPause()

// Disable element lookup
watch(draggedItem, (dragging) => {
  if (dragging) {
    dragTrackStart()
    return
  }

  dragTrackPause()
}, { immediate: true })

// Find current index and position on both desktop and mobile devices
watchEffect(() => {
  if (draggedItem.value) {
    const dragItem = (hoveredElement.value as HTMLElement)?.closest('.drag-item') as HTMLElement
    if (!dragItem) return

    hoveredIndex.value = getIndex(dragItem)
    const { y } = dragItem.getBoundingClientRect()
    position.value = screenY.value - y < props.size / 2 ? 'before' : 'after'
  }
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

const el = useCurrentElement()
const resize = () => {
  const element = el.value as HTMLElement
  containerSize.top = element.offsetTop
  containerSize.bottom = element.offsetHeight + containerSize.top
}

// Scrolling when item held near top/bottom border
let lastDate = +new Date()
const { resume, pause } = useRafFn(() => {
  const now = +new Date()
  const direction = scrollDirection.value

  if (direction && el.value?.children[0] && !isTouch.value) {
    el.value.children[0].scrollTop += 200 / (now - lastDate) * (direction === 'up' ? -1 : 1)
  }

  lastDate = now
}, { immediate: false })

const virtualList = ref()
const scrollToIndex = (index: number, block: 'center' | 'start' | 'end' = 'start') => {
  if (!virtualList.value) return

  const position = block === 'start'
    ? index * props.size
    : block === 'end'
      ? (index + 1) * props.size - virtualList.value.$el.offsetHeight
      : (index + 0.5) * props.size - virtualList.value.$el.offsetHeight / 2

  virtualList.value.scrollToPosition(position)
}

defineExpose({
  scroller: virtualList,
  scrollToIndex,
  cleanup
})
</script>

<template>
  <div>
    <recycle-scroller
      ref="virtualList"
      class="virtual-list drag-container"
      key-field="key"
      :items="list"
      :item-size="size"
      :grid-items="1"
      @mousedown="onMousedown"
      @touchstart="onMousedown"
      @touchmove="onTouchmove"
      @resize="resize"
      @visible="emit('visible')"
    >
      <template #before>
        <slot name="header" />
      </template>

      <template #default="{ item, index }">
        <slot
          :classlist="[draggedItem && hoveredIndex === index && `drop-${position}`, 'drag-item']"
          :item="item"
          :index="index"
        />
      </template>

      <template #after>
        <slot name="footer" />
      </template>
    </recycle-scroller>

    <div
      ref="ghostContainer"
      class="ghost-container"
    />
  </div>
</template>

<style lang="scss">
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

  &:last-child {
    box-shadow: inset 0 2px 0 var(--vibrant-color);
  }
}

.drop-after {
  box-shadow: 0  1px 0 var(--vibrant-color),
        inset 0 -1px 0 var(--vibrant-color);

  &:last-child {
    box-shadow: inset 0 -2px 0 var(--vibrant-color);
  }
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

.vue-recycle-scroller__item-view {
  width: 100% !important;
}
</style>
