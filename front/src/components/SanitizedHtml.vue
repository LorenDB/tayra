<script setup lang="ts">
import DOMPurify from 'dompurify'
import { computed, h } from 'vue'

interface Props {
  tag?: string
  html: string
}

const props = withDefaults(defineProps<Props>(), {
  tag: 'div'
})

DOMPurify.addHook('afterSanitizeAttributes', (node) => {
  // set all elements owning target to target=_blank
  if ('target' in node) {
    node.setAttribute('target', '_blank')
  }
})

const html = computed(() => DOMPurify.sanitize(props.html))
const root = () => h(props.tag, { innerHTML: html.value })
</script>

<template>
  <root />
</template>
