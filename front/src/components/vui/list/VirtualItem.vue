<script setup lang="ts">
interface Props {
  component: unknown
  index: number
  dragClassHandler: (index: number) => string
}

defineProps<Props>()
</script>

<template>
  <Component
    :is="component"
    :class="dragClassHandler(index)"
    :index="index"
    :data-index="index"
  />
</template>
