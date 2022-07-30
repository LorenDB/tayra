<script setup lang="ts">
import type { BackendError } from '~/types'

import { ref } from 'vue'

// TODO (wvffle): Remove this component
import axios from 'axios'

interface Emits {
  (e: 'action-done', data: any): void
  (e: 'action-error', error: BackendError): void
}

interface Props {
  method: 'get' | 'post' | 'put' | 'patch' | 'delete'
  url: string
}

const emit = defineEmits<Emits>()
const props = defineProps<Props>()

const isLoading = ref(false)
const ajaxCall = async () => {
  isLoading.value = true

  try {
    const response = await axios[props.method](props.url)
    emit('action-done', response.data)
  } catch (error) {
    emit('action-error', error as BackendError)
  }

  isLoading.value = false
}
</script>

<template>
  <button
    :class="['ui', {loading: isLoading}, 'button']"
    @click="ajaxCall"
  >
    <slot />
  </button>
</template>
