<script setup lang="ts">
import { computed } from 'vue'
import { useToggle } from '@vueuse/core'

interface Props {
  content: string
  length?: number
}

const props = withDefaults(defineProps<Props>(), {
  length: 150
})

const [expanded, toggleExpanded] = useToggle(false)
const truncated = computed(() => props.content.slice(0, props.length))
</script>

<template>
  <div class="expandable-wrapper">
    <div :class="['expandable-content', { expandable: truncated.length < content.length, expanded }]">
      <slot>{{ content }}</slot>
    </div>
    <a
      v-if="truncated.length < content.length"
      role="button"
      @click.prevent="toggleExpanded()"
    >
      <br>
      <translate
        v-if="expanded"
        key="1"
        translate-context="*/*/Button,Label"
      >Show less</translate>
      <translate
        v-else
        key="2"
        translate-context="*/*/Button,Label"
      >Show more</translate>
    </a>
  </div>
</template>
