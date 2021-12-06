<template>
  <time :datetime="`${duration}s`">
    {{ duration | duration }}
  </time>
</template>
<script>
export default {
  props: {
    duration: { type: Object, required: true }
  }
}
</script>
