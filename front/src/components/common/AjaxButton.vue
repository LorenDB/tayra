<script setup lang="ts">
import type { BackendError } from '~/types'

import { ref } from 'vue'

import axios from 'axios'

interface Events {
  (e: 'action-done', data: any): void
  (e: 'action-error', error: BackendError): void
}

interface Props {
  method: 'get' | 'post' | 'put' | 'patch' | 'delete'
  url: string
}

const emit = defineEmits<Events>()
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
