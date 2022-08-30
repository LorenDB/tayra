<script setup lang="ts">
import axios from 'axios'
import { useVModel, watchDebounced, useTextareaAutosize, syncRef } from '@vueuse/core'
import { ref, computed, watchEffect, onMounted, nextTick } from 'vue'
import { useGettext } from 'vue3-gettext'

interface Events {
  (e: 'update:modelValue', value: string): void
}

interface Props {
  modelValue: string
  placeholder?: string
  autofocus?: boolean
  permissive?: boolean
  required?: boolean
  charLimit?: number
}

const emit = defineEmits<Events>()
const props = withDefaults(defineProps<Props>(), {
  placeholder: undefined,
  autofocus: false,
  charLimit: 5000,
  permissive: false,
  required: false
})

const { $pgettext } = useGettext()
const { textarea, input } = useTextareaAutosize()
const value = useVModel(props, 'modelValue', emit)
syncRef(value, input)

const isPreviewing = ref(false)
const preview = ref()
const isLoadingPreview = ref(false)

const labels = computed(() => ({
  placeholder: props.placeholder ?? $pgettext('*/Form/Placeholder', 'Write a few words here…')
}))

const remainingChars = computed(() => props.charLimit - props.modelValue.length)

const loadPreview = async () => {
  isLoadingPreview.value = true
  try {
    const response = await axios.post('text-preview/', { text: value.value, permissive: props.permissive })
    preview.value = response.data.rendered
  } catch (error) {
    console.error(error)
  }
  isLoadingPreview.value = false
}

watchDebounced(value, async () => {
  await loadPreview()
}, { immediate: true, debounce: 500 })

watchEffect(async () => {
  if (isPreviewing.value) {
    if (value.value && !preview.value && !isLoadingPreview.value) {
      await loadPreview()
    }

    return
  }

  await nextTick()
  textarea.value.focus()
})

onMounted(async () => {
  if (props.autofocus) {
    await nextTick()
    textarea.value.focus()
  }
})
</script>

<template>
  <div class="content-form ui segments">
    <div class="ui segment">
      <div class="ui tiny secondary pointing menu">
        <button
          :class="[{active: !isPreviewing}, 'item']"
          @click.prevent="isPreviewing = false"
        >
          <translate translate-context="*/Form/Menu.item">
            Write
          </translate>
        </button>
        <button
          :class="[{active: isPreviewing}, 'item']"
          @click.prevent="isPreviewing = true"
        >
          <translate translate-context="*/Form/Menu.item">
            Preview
          </translate>
        </button>
      </div>
      <template v-if="isPreviewing">
        <div
          v-if="isLoadingPreview"
          class="ui placeholder"
        >
          <div class="paragraph">
            <div class="line" />
            <div class="line" />
            <div class="line" />
            <div class="line" />
          </div>
        </div>
        <p v-else-if="!preview">
          <translate translate-context="*/Form/Paragraph">
            Nothing to preview.
          </translate>
        </p>
        <sanitized-html
          v-else
          :html="preview"
        />
      </template>
      <template v-else>
        <div class="ui transparent input">
          <textarea
            ref="textarea"
            v-model="value"
            :required="required"
            :placeholder="labels.placeholder"
          />
        </div>
        <div class="ui very small hidden divider" />
      </template>
    </div>
    <div class="ui bottom attached segment">
      <span
        v-if="charLimit"
        :class="['right', 'floated', {'ui danger text': remainingChars < 0}]"
      >
        {{ remainingChars }}
      </span>
      <p>
        <translate translate-context="*/Form/Paragraph">
          Markdown syntax is supported.
        </translate>
      </p>
    </div>
  </div>
</template>
