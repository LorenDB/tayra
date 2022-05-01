<script setup lang="ts">
import { useClipboard, useVModel } from '@vueuse/core'

interface Props {
  modelValue: string
  buttonClasses?: string
  id?: string
}

const props = withDefaults(defineProps<Props>(), {
  buttonClasses: 'accent',
  id: 'copy-input'
})

const emit = defineEmits(['update:modelValue'])
const value = useVModel(props, 'modelValue', emit)

const { copy, isSupported: canCopy, copied } = useClipboard({ source: value, copiedDuring: 5000 })
</script>

<template>
  <div class="ui fluid action input component-copy-input">
    <p
      v-if="copied"
      class="message"
    >
      <translate translate-context="Content/*/Paragraph">
        Text copied to clipboard!
      </translate>
    </p>
    <input
      :id="id"
      v-model="value"
      :name="id"
      type="text"
      readonly
    >
    <button
      :class="['ui', buttonClasses, 'right', 'labeled', 'icon', 'button']"
      :disabled="!canCopy || undefined"
      @click="copy()"
    >
      <i class="copy icon" />
      <translate translate-context="*/*/Button.Label/Short, Verb">
        Copy
      </translate>
    </button>
  </div>
</template>
