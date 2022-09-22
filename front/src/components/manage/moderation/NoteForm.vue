<script setup lang="ts">
import type { Note, BackendError } from '~/types'

import axios from 'axios'
import { ref, computed } from 'vue'
import { useI18n } from 'vue-i18n'

interface Events {
  (e: 'created', note: Note): void
}

interface Props {
  target: Note
}

const emit = defineEmits<Events>()
const props = defineProps<Props>()

const { t } = useI18n()
const labels = computed(() => ({
  summaryPlaceholder: t('components.manage.moderation.NoteForm.placeholder.summary')
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
        {{ $t('components.manage.moderation.NoteForm.header.failure') }}
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
      {{ $t('components.manage.moderation.NoteForm.button.add') }}
    </button>
  </form>
</template>
