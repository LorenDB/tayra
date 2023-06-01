<script setup lang="ts">
import { useVModel } from '@vueuse/core'

interface Events {
  (e: 'update:modelValue', value: boolean): void
}

interface Props {
  modelValue: boolean
}

const emit = defineEmits<Events>()
const props = defineProps<Props>()
const value = useVModel(props, 'modelValue', emit)
</script>

<template>
  <a
    role="button"
    class="collapse link"
    @click.prevent="value = !value"
  >
    <span v-if="value">
      {{ $t('components.common.CollapseLink.button.expand') }}
    </span>
    <span v-else>
      {{ $t('components.common.CollapseLink.button.collapse') }}
    </span>
    <i :class="[{ down: !value, right: value }, 'angle', 'icon']" />
  </a>
</template>
