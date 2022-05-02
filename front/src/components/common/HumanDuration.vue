<script setup lang="ts">
import { toRefs } from '@vueuse/core'
import { computed } from 'vue'
import time from '~/utils/time'

interface Props {
  duration: number
}

const props = defineProps<Props>()
const { duration } = toRefs(props)
const parsedDuration = computed(() => time.parse(duration.value))
</script>

<template>
  <time :datetime="`${duration}s`">
    {{ parsedDuration }}
  </time>
</template>
