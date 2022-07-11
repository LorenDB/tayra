<script setup lang="ts">

interface Props {
  content: string
}

defineProps<Props>()
</script>

<template>
  <span
    class="tooltip"
    :data-tooltip="content"
  ><i class="question circle icon" /></span>
</template>
