<template>
  <span
    class="tooltip"
    :data-tooltip="content"
  ><i class="question circle icon" /></span>
</template>

<script>

export default {
  props: {
    content: { type: String, required: true }
  }
}
</script>
