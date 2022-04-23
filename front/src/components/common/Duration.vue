<template>
  <span>
    <translate
      v-if="durationData.hours > 0"
      translate-context="Content/*/Paragraph"
      :translate-params="{minutes: durationData.minutes, hours: durationData.hours}"
    >%{ hours } h %{ minutes } min</translate>
    <translate
      v-else
      translate-context="Content/*/Paragraph"
      :translate-params="{minutes: durationData.minutes}"
    >%{ minutes } min</translate>
  </span>
</template>
<script>
import { secondsToObject } from '~/init/filters'

export default {
  props: { seconds: { type: Number, default: null } },
  computed: {
    durationData () {
      return secondsToObject(this.seconds)
    }
  }
}
</script>
