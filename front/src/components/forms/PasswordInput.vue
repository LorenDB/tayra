<script setup lang="ts">
import { computed, ref } from 'vue'
import { useGettext } from 'vue3-gettext'
import { useClipboard, useVModel } from '@vueuse/core'
import { useStore } from '~/store'

interface Props {
  modelValue: string
  defaultShow?: boolean
  copyButton?: boolean
  fieldId: string
}

const props = withDefaults(defineProps<Props>(), {
  defaultShow: false,
  copyButton: false
})

const emit = defineEmits(['update:modelValue'])
const value = useVModel(props, 'modelValue', emit)

const showPassword = ref(props.defaultShow)

const { $pgettext } = useGettext()
const labels = computed(() => ({
  title: $pgettext('Content/Settings/Button.Tooltip/Verb', 'Show/hide password'),
  copy: $pgettext('*/*/Button.Label/Short, Verb', 'Copy')
}))

const passwordInputType = computed(() => showPassword.value ? 'text' : 'password')

const store = useStore()
const { isSupported: canCopy, copy } = useClipboard({ source: value })
const copyPassword = () => {
  copy()
  store.commit('ui/addMessage', {
    content: $pgettext('Content/*/Paragraph', 'Text copied to clipboard!'),
    date: new Date()
  })
}
</script>

<template>
  <div class="ui fluid action input">
    <input
      :id="fieldId"
      v-model="value"
      required
      name="password"
      :type="passwordInputType"
    >
    <button
      type="button"
      :title="labels.title"
      class="ui icon button"
      @click.prevent="showPassword = !showPassword"
    >
      <i class="eye icon" />
    </button>
    <button
      v-if="copyButton && canCopy"
      type="button"
      class="ui icon button"
      :title="labels.copy"
      @click.prevent="copyPassword"
    >
      <i class="copy icon" />
    </button>
  </div>
</template>
