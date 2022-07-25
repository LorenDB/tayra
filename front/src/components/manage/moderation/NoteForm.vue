<script setup lang="ts">
import type { Note, BackendError } from '~/types'

import axios from 'axios'
import { ref, computed } from 'vue'
import { useGettext } from 'vue3-gettext'

interface Emits {
  (e: 'created', note: Note): void
}

interface Props {
  target: Note
}

const emit = defineEmits<Emits>()
const props = defineProps<Props>()

const { $pgettext } = useGettext()
const labels = computed(() => ({
  summaryPlaceholder: $pgettext('Content/Moderation/Placeholder', 'Describe what actions have been taken, or any other related updates…')
}))

const summary = ref('')

const isLoading = ref(false)
const errors = ref([] as string[])
const submit = async () => {
  isLoading.value = true
  errors.value = []

  try {
    const response = await axios.post('manage/moderation/notes/', {
      target: props.target,
      summary: summary.value
    })

    emit('created', response.data)
    summary.value = ''
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}
</script>

<template>
  <form
    class="ui form"
    @submit.prevent="submit()"
  >
    <div
      v-if="errors.length > 0"
      role="alert"
      class="ui negative message"
    >
      <h4 class="header">
        <translate translate-context="Content/Moderation/Error message.Title">
          Error while submitting note
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
    <div class="field">
      <content-form
        v-model="summary"
        field-id="change-summary"
        :required="true"
        :rows="3"
        :placeholder="labels.summaryPlaceholder"
      />
    </div>
    <button
      :class="['ui', {'loading': isLoading}, 'right', 'floated', 'button']"
      type="submit"
      :disabled="isLoading"
    >
      <translate translate-context="Content/Moderation/Button.Label/Verb">
        Add note
      </translate>
    </button>
  </form>
</template>
