<script setup lang="ts">
import moment from 'moment'
import { computed } from 'vue'

interface Props {
  seconds?: number
}

const props = defineProps<Props>()
const duration = computed(() => {
  const { minutes, hours } = moment.duration(props.seconds, 'seconds')
  return { minutes: minutes(), hours: hours() }
})
</script>

<template>
  <span>
    <translate
      v-if="duration.hours > 0"
      translate-context="Content/*/Paragraph"
      :translate-params="duration"
    >%{ hours } h %{ minutes } min</translate>
    <translate
      v-else
      translate-context="Content/*/Paragraph"
      :translate-params="duration"
    >%{ minutes } min</translate>
  </span>
</template>
