<script setup lang="ts">
import { refAutoReset, toRefs } from '@vueuse/core'
import { watch } from 'vue'

interface Props {
  isLoading: boolean
  size?: string
}

const { isLoading, size } = toRefs(withDefaults(defineProps<Props>(), {
  size: 'small'
}))

const isDone = refAutoReset(false, 2000)
watch(isLoading, loading => {
  isDone.value = !loading
})
</script>

<template>
  <span
    v-if="isLoading || isDone"
    class="feedback"
  >
    <span
      v-if="isLoading"
      :class="['ui', 'active', size, 'inline', 'loader']"
    />
    <i
      v-if="isDone"
      :class="['success', size, 'check', 'icon']"
    />
  </span>
</template>
