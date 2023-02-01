<script setup lang="ts">

interface Props {
  content: string | false
  tag?: string
}

withDefaults(defineProps<Props>(), {
  tag: 'span'
})
</script>

<template>
  <component
    :is="tag"
    v-if="content"
    :data-tooltip="content"
    class="tooltip"
  >
    <slot>
      <i class="question circle icon" />
    </slot>
  </component>
  <slot v-else />
</template>
