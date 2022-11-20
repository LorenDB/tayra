<script setup lang="ts">
import type { ObjectId, RadioConfig } from '~/store/radios'

import { useGettext } from 'vue3-gettext'
import { useStore } from '~/store'
import { computed } from 'vue'

interface Props {
  customRadioId?: number | null
  type?: string
  clientOnly?: boolean
  objectId?: ObjectId | number | string | null
  radioConfig?: RadioConfig | null
}

const props = withDefaults(defineProps<Props>(), {
  customRadioId: null,
  type: '',
  clientOnly: false,
  objectId: null,
  radioConfig: null
})

const store = useStore()
const running = computed(() => {
  if (!store.state.radios.running) {
    return false
  }

  const { current } = store.state.radios
  return current?.type === props.type
    && current?.customRadioId === props.customRadioId
    && (
      (typeof props.objectId === 'object' && current.objectId?.fullUsername === props.objectId?.fullUsername)
        || current.objectId === props.objectId
    )
})

const { $pgettext } = useGettext()
const buttonLabel = computed(() => {
  switch (props.radioConfig?.type) {
    case 'tag':
      return running.value
        ? $pgettext('*/Player/Button.Label/Short, Verb', 'Stop tags radio')
        : $pgettext('*/Player/Button.Label/Short, Verb', 'Start tags radio')
    case 'artist':
      return running.value
        ? $pgettext('*/Player/Button.Label/Short, Verb', 'Stop artists radio')
        : $pgettext('*/Player/Button.Label/Short, Verb', 'Start artists radio')
    case 'playlist':
      return running.value
        ? $pgettext('*/Player/Button.Label/Short, Verb', 'Stop playlists radio')
        : $pgettext('*/Player/Button.Label/Short, Verb', 'Start playlists radio')
    default:
      return running.value
        ? $pgettext('*/Player/Button.Label/Short, Verb', 'Stop radio')
        : $pgettext('*/Queue/Button.Label/Short, Verb', 'Play radio')
  }
})

const toggleRadio = () => {
  if (running.value) {
    return store.dispatch('radios/stop')
  }

  return store.dispatch('radios/start', {
    type: props.type,
    objectId: props.objectId,
    customRadioId: props.customRadioId,
    clientOnly: props.clientOnly,
    config: props.radioConfig
  })
}
</script>

<template>
  <button
    :class="['ui', 'primary', {'inverted': running}, 'icon', 'labeled', 'button']"
    @click="toggleRadio"
  >
    <i
      class="ui feed icon"
      role="button"
    />
    {{ buttonLabel }}
  </button>
</template>
