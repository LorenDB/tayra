<script setup lang="ts">
import type { BackendError } from '~/types'

import { ref, computed } from 'vue'
import { whenever } from '@vueuse/core'

import axios from 'axios'
import clip from 'text-clipper'

interface Emits {
  (e: 'updated', data: unknown): void
}

interface Props {
  content?: { text?: string, html?: string } | null
  fieldName?: string
  updateUrl?: string
  canUpdate?: boolean
  fetchHtml?: boolean
  permissive?: boolean
  truncateLength?: number
}

const emit = defineEmits<Emits>()
const props = withDefaults(defineProps<Props>(), {
  content: null,
  fieldName: 'description',
  updateUrl: '',
  canUpdate: true,
  fetchHtml: false,
  permissive: false,
  truncateLength: 500
})

const preview = ref('')
const fetchPreview = async () => {
  const response = await axios.post('text-preview/', { text: props.content?.text ?? '', permissive: props.permissive })
  preview.value = response.data.rendered
}

whenever(() => props.fetchHtml, fetchPreview)

const truncatedHtml = computed(() => clip(props.content?.html ?? '', props.truncateLength, {
  html: true,
  maxLines: 3
}))

const showMore = ref(false)
const html = computed(() => props.fetchHtml
  ? preview.value
  : props.truncateLength > 0 && !showMore.value
    ? truncatedHtml.value
    : props.content?.html ?? ''
)

const isTruncated = computed(() => props.truncateLength > 0 && truncatedHtml.value.length < (props.content?.html ?? '').length)

const isUpdating = ref(false)
const text = ref(props.content?.text ?? '')
const isLoading = ref(false)
const errors = ref([] as string[])
const submit = async () => {
  errors.value = []
  isLoading.value = true

  try {
    const response = await axios.patch(props.updateUrl, {
      [props.fieldName]: text.value
        ? { content_type: 'text/markdown', text: text.value }
        : null
    })

    emit('updated', response.data)
    isUpdating.value = false
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}
</script>

<template>
  <div>
    <template v-if="content && !isUpdating">
      <sanitized-html :html="html" />
      <template v-if="isTruncated">
        <div class="ui small hidden divider" />
        <a
          v-if="showMore === false"
          href=""
          @click.stop.prevent="showMore = true"
        >
          <translate translate-context="*/*/Button,Label">Show more</translate>
        </a>
        <a
          v-else
          href=""
          @click.stop.prevent="showMore = false"
        >
          <translate translate-context="*/*/Button,Label">Show less</translate>
        </a>
      </template>
    </template>
    <p v-else-if="!isUpdating">
      <translate translate-context="*/*/Placeholder">
        No description available
      </translate>
    </p>
    <template v-if="!isUpdating && canUpdate && updateUrl">
      <div class="ui hidden divider" />
      <span
        role="button"
        @click="isUpdating = true"
      >
        <i class="pencil icon" />
        <translate translate-context="Content/*/Button.Label/Verb">Edit</translate>
      </span>
    </template>
    <form
      v-if="isUpdating"
      class="ui form"
      @submit.prevent="submit()"
    >
      <div
        v-if="errors.length > 0"
        role="alert"
        class="ui negative message"
      >
        <h4 class="header">
          <translate translate-context="Content/Channels/Error message.Title">
            Error while updating description
          </translate>
        </h4>
        <ul class="list">
          <li
            v-for="(error, key) in errors"
            :key="key"
          >
            {{ error }}
          </li>
        </ul>
      </div>
      <content-form
        v-model="text"
        :autofocus="true"
      />
      <a
        class="left floated"
        @click.prevent="isUpdating = false"
      >
        <translate translate-context="*/*/Button.Label/Verb">Cancel</translate>
      </a>
      <button
        :class="['ui', {'loading': isLoading}, 'right', 'floated', 'button']"
        type="submit"
        :disabled="isLoading"
      >
        <translate translate-context="Content/Channels/Button.Label/Verb">
          Update description
        </translate>
      </button>
      <div class="ui clearing hidden divider" />
    </form>
  </div>
</template>
