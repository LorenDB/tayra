<script setup lang="ts">
import $ from 'jquery'
import { useFocusTrap } from '@vueuse/integrations/useFocusTrap'
import { computed, onBeforeUnmount, ref, watchEffect } from 'vue'
import { useVModel } from '@vueuse/core'
import { useStore } from '~/store'

interface Events {
  (e: 'update:show', show: boolean): void
  (e: 'approved'): void
  (e: 'deny'): void
  (e: 'show'): void
  (e: 'hide'): void
}

interface Props {
  show: boolean
  fullscreen?: boolean
  scrolling?: boolean
  additionalClasses?: string[]
}

const emit = defineEmits<Events>()
const props = withDefaults(defineProps<Props>(), {
  fullscreen: true,
  scrolling: false,
  additionalClasses: () => []
})

const modal = ref()
const { activate, deactivate, pause, unpause } = useFocusTrap(modal, {
  allowOutsideClick: true
})

const show = useVModel(props, 'show', emit)

const control = ref<JQuery | undefined>()
const initModal = () => {
  control.value = $(modal.value).modal({
    duration: 100,
    onApprove: () => emit('approved'),
    onDeny: () => emit('deny'),
    onHidden: () => (show.value = false)
  })
}

watchEffect(() => {
  if (show.value) {
    initModal()
    emit('show')
    control.value?.modal('show')
    activate()
    unpause()
    document.body.classList.add('scrolling')
    return
  }

  if (control.value) {
    emit('hide')
    control.value.modal('hide')
    control.value.remove()
    deactivate()
    pause()
    document.body.classList.remove('scrolling')
  }
})

onBeforeUnmount(() => {
  control.value?.modal('hide')
})

const store = useStore()
const classes = computed(() => [
  ...props.additionalClasses,
  'ui', 'modal',
  {
    active: show.value,
    scrolling: props.scrolling,
    'overlay fullscreen': props.fullscreen && ['phone', 'tablet'].includes(store.getters['ui/windowSize'])
  }
])
</script>

<template>
  <div
    ref="modal"
    :class="classes"
  >
    <i
      tabindex="0"
      class="close inside icon"
    />
    <slot v-if="show" />
  </div>
</template>
