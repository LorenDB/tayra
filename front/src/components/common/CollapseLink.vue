<script setup lang="ts">
import { useVModel } from '@vueuse/core'

interface Props {
  modelValue: boolean
}

const props = defineProps<Props>()
const emit = defineEmits(['update:modelValue'])
const value = useVModel(props, 'modelValue', emit)
</script>

<template>
  <a
    role="button"
    class="collapse link"
    @click.prevent="value = !value"
  >
    <translate
      v-if="value"
      translate-context="*/*/Button,Label"
    >
      Expand
    </translate>
    <translate
      v-else
      translate-context="*/*/Button,Label"
    >
      Collapse
    </translate>
    <i :class="[{ down: !value, right: value }, 'angle', 'icon']" />
  </a>
</template>
