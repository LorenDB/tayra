<script setup lang="ts">
import type { BackendError } from '~/types'

import { useI18n } from 'vue-i18n'
import { computed, ref } from 'vue'

import axios from 'axios'

interface Events {
  (e: 'scanned', data: object): void
}

const emit = defineEmits<Events>()

const { t } = useI18n()

const labels = computed(() => ({
  placeholder: t('views.content.remote.ScanForm.placeholder.url'),
  submitLibrarySearch: t('views.content.remote.ScanForm.button.submit')
}))

const errors = ref([] as string[])
const isLoading = ref(false)
const query = ref('')
const scan = async () => {
  if (!query.value) return
  isLoading.value = true
  errors.value = []

  try {
    const response = await axios.post('federation/libraries/fetch/', { fid: query.value })
    emit('scanned', response.data)
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}
</script>

<template>
  <form
    class="ui form"
    @submit.prevent="scan"
  >
    <div
      v-if="errors.length > 0"
      role="alert"
      class="ui negative message"
    >
      <h4 class="header">
        {{ $t('views.content.remote.ScanForm.header.failure') }}
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
    <div class="ui field">
      <label for="library-search">{{ $t('views.content.remote.ScanForm.label.search') }}</label>
      <div :class="['ui', 'action', {loading: isLoading}, 'input']">
        <input
          id="library-search"
          v-model="query"
          name="url"
          :placeholder="labels.placeholder"
          type="url"
        >
        <button
          :aria-label="labels.submitLibrarySearch"
          type="submit"
          :class="['ui', 'icon', {loading: isLoading}, 'button']"
        >
          <i class="search icon" />
        </button>
      </div>
    </div>
  </form>
</template>
