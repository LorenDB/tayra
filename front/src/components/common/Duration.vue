<script setup lang="ts">
import moment from 'moment'
import { computed } from 'vue'

interface Props {
  seconds?: number
}

const props = withDefaults(defineProps<Props>(), {
  seconds: 0
})

const duration = computed(() => {
  const momentDuration = moment.duration(props.seconds, 'seconds')
  return { minutes: momentDuration.minutes(), hours: momentDuration.hours() }
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
