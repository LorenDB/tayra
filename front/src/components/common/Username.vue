<script setup lang="ts">
interface Props {
  username: string
}

defineProps<Props>()
</script>

<template>
  <span>{{ username }}</span>
</template>