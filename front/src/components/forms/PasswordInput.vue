<script setup lang="ts">
import { computed, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useClipboard, useVModel } from '@vueuse/core'
import { useStore } from '~/store'

interface Events {
  (e: 'update:modelValue', value: string): void
}

interface Props {
  modelValue: string
  defaultShow?: boolean
  copyButton?: boolean
  fieldId: string
}

const emit = defineEmits<Events>()
const props = withDefaults(defineProps<Props>(), {
  defaultShow: false,
  copyButton: false
})

const value = useVModel(props, 'modelValue', emit)

const showPassword = ref(props.defaultShow)

const { t } = useI18n()
const labels = computed(() => ({
  title: t('components.forms.PasswordInput.title'),
  copy: t('components.forms.PasswordInput.button.copy')
}))

const passwordInputType = computed(() => showPassword.value ? 'text' : 'password')

const store = useStore()
const { isSupported: canCopy, copy } = useClipboard({ source: value })
const copyPassword = () => {
  copy()
  store.commit('ui/addMessage', {
    content: t('components.forms.PasswordInput.message.copy'),
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
