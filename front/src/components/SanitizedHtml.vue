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

const html = computed(() => DOMPurify.sanitize(props.html))
const root = () => h(props.tag, { innerHTML: html.value })
</script>

<template>
  <root />
</template>
