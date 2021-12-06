<template>
  <span>{{ username }}</span>
</template>
<script>
export default {
  props: { username: { type: String, required: true } }
}
</script>
