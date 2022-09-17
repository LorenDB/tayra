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
    <span
      v-if="duration.hours > 0"
    >{{ $t('components.common.Duration.hoursFormat', {hours: duration.hours, minutes: duration.minutes}) }}</span>
    <span
      v-else
    >{{ $t('components.common.Duration.minutesFormat', {minutes: duration.minutes}) }}</span>
  </span>
</template>
