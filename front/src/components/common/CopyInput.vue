<script setup lang="ts">
import { toRefs, useClipboard } from '@vueuse/core'

interface Props {
  value: string
  buttonClasses?: string
  id?: string
}

const props = withDefaults(defineProps<Props>(), {
  buttonClasses: 'accent',
  id: 'copy-input'
})

const { value } = toRefs(props)
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
      :value="value"
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
