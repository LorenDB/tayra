<script setup lang="ts">
import type { BackendError } from '~/types'

import axios from 'axios'
import SemanticModal from '~/components/semantic/Modal.vue'
import { useTimeoutFn } from '@vueuse/core'
import { ref } from 'vue'

interface Events {
  (e: 'refresh'): void
}

interface Props {
  url: string
}

const emit = defineEmits<Events>()
const props = defineProps<Props>()

const MAX_POLLS = 15

const pollsCount = ref(0)
const showModal = ref(false)
const data = ref()
const errors = ref([] as string[])

const isLoading = ref(false)
const isPolling = ref(false)

const fetch = async () => {
  showModal.value = true
  isLoading.value = true
  isPolling.value = false
  errors.value = []
  pollsCount.value = 0
  data.value = undefined

  try {
    const response = await axios.post(props.url)
    data.value = response.data
    startPolling()
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}

const poll = async () => {
  isPolling.value = true
  showModal.value = true

  try {
    const response = await axios.get(`federation/fetches/${data.value?.id}/`)
    data.value = response.data

    if (response.data.status === 'pending' && pollsCount.value++ < MAX_POLLS) {
      startPolling()
    }
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isPolling.value = false
}

const { start: startPolling } = useTimeoutFn(poll, 1000, { immediate: false })
</script>

<template>
  <div
    role="button"
    @click="fetch"
  >
    <div>
      <slot />
    </div>
    <semantic-modal
      v-model:show="showModal"
      class="small"
    >
      <h3 class="header">
        {{ $t('components.federation.FetchButton.header.refresh') }}
      </h3>
      <div class="scrolling content">
        <template v-if="data && data.status != 'pending'">
          <div
            v-if="data.status === 'skipped'"
            class="ui message"
          >
            <h4 class="header">
              {{ $t('components.federation.FetchButton.header.skipped') }}
            </h4>
            <p>
              {{ $t('components.federation.FetchButton.description.skipped') }}
            </p>
          </div>
          <div
            v-else-if="data.status === 'finished'"
            class="ui success message"
          >
            <h4 class="header">
              {{ $t('components.federation.FetchButton.header.success') }}
            </h4>
            <p>
              {{ $t('components.federation.FetchButton.description.success') }}
            </p>
          </div>
          <div
            v-else-if="data.status === 'errored'"
            class="ui error message"
          >
            <h4 class="header">
              {{ $t('components.federation.FetchButton.header.failure') }}
            </h4>
            <p>
              {{ $t('components.federation.FetchButton.description.failure') }}
            </p>
            <table class="ui very basic collapsing celled table">
              <tbody>
                <tr>
                  <td>
                    {{ $t('components.federation.FetchButton.table.error.label.type') }}
                  </td>
                  <td>
                    {{ data.detail.error_code }}
                  </td>
                </tr>
                <tr>
                  <td>
                    {{ $t('components.federation.FetchButton.table.error.label.detail') }}
                  </td>
                  <td>
                    <span v-if="data.detail.error_code === 'http' && data.detail.status_code">
                      {{ $t('components.federation.FetchButton.table.error.value.httpStatus', {status: data.detail.status_code}) }}
                    </span>
                    <span v-else-if="['http', 'request'].includes(data.detail.error_code)">
                      {{ $t('components.federation.FetchButton.table.error.value.httpError') }}
                    </span>
                    <span v-else-if="data.detail.error_code === 'timeout'">
                      {{ $t('components.federation.FetchButton.table.error.value.timeoutError') }}
                    </span>
                    <span v-else-if="data.detail.error_code === 'connection'">
                      {{ $t('components.federation.FetchButton.table.error.value.connectionError') }}
                    </span>
                    <span v-else-if="['invalid_json', 'invalid_jsonld', 'missing_jsonld_type'].includes(data.detail.error_code)">
                      {{ $t('components.federation.FetchButton.table.error.value.invalidJsonError') }}
                    </span>
                    <span v-else-if="data.detail.error_code === 'validation'">
                      {{ $t('components.federation.FetchButton.table.error.value.invalidAttributesError') }}
                    </span>
                    <span v-else-if="data.detail.error_code === 'unhandled'">
                      {{ $t('components.federation.FetchButton.table.error.value.unknownError') }}
                    </span>
                    <span v-else>
                      {{ $t('components.federation.FetchButton.table.error.value.unknownError') }}
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </template>
        <div
          v-else-if="isLoading"
          class="ui active inverted dimmer"
        >
          <div class="ui text loader">
            {{ $t('components.federation.FetchButton.loader.fetchRequest') }}
          </div>
        </div>
        <div
          v-else-if="isPolling"
          class="ui active inverted dimmer"
        >
          <div class="ui text loader">
            {{ $t('components.federation.FetchButton.loader.awaitingResult') }}
          </div>
        </div>
        <div
          v-if="errors.length > 0"
          role="alert"
          class="ui negative message"
        >
          <h4 class="header">
            {{ $t('components.federation.FetchButton.header.saveFailure') }}
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
        <div
          v-else-if="data && data.status === 'pending' && pollsCount >= MAX_POLLS"
          role="alert"
          class="ui warning message"
        >
          <h4 class="header">
            {{ $t('components.federation.FetchButton.header.pending') }}
          </h4>
          <p>
            {{ $t('components.federation.FetchButton.description.pending') }}
          </p>
        </div>
      </div>
      <div class="actions">
        <button class="ui basic cancel button">
          {{ $t('components.federation.FetchButton.button.close') }}
        </button>
        <button
          v-if="data && data.status === 'finished'"
          class="ui confirm success button"
          @click.prevent="showModal = false; emit('refresh')"
        >
          {{ $t('components.federation.FetchButton.button.reload') }}
        </button>
      </div>
    </semantic-modal>
  </div>
</template>
