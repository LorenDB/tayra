<script setup lang="ts">
import { momentFormat } from '~/utils/filters'
import { useTimeAgo } from '@vueuse/core'
import { computed } from 'vue'

interface Props {
  date: string,
  icon?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  icon: false
})

const date = computed(() => new Date(props.date))
// TODO (wvffle): Translate useTimeAgo
const realDate = useTimeAgo(date)
</script>

<template>
  <time
    :datetime="date"
    :title="momentFormat(date)"
  >
    <i
      v-if="props.icon"
      class="outline clock icon"
    />
    {{ realDate }}
  </time>
</template>
