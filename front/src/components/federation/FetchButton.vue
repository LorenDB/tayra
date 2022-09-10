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
        Refreshing object from remote server…
      </h3>
      <div class="scrolling content">
        <template v-if="data && data.status != 'pending'">
          <div
            v-if="data.status === 'skipped'"
            class="ui message"
          >
            <h4 class="header">
              Refresh was skipped
            </h4>
            <p>
              The remote server answered, but returned data was unsupported by Funkwhale.
            </p>
          </div>
          <div
            v-else-if="data.status === 'finished'"
            class="ui success message"
          >
            <h4 class="header">
              Refresh successful
            </h4>
            <p>
              Data was refreshed successfully from remote server.
            </p>
          </div>
          <div
            v-else-if="data.status === 'errored'"
            class="ui error message"
          >
            <h4 class="header">
              Refresh error
            </h4>
            <p>
              An error occurred while trying to refresh data:
            </p>
            <table class="ui very basic collapsing celled table">
              <tbody>
                <tr>
                  <td>
                    Error type
                  </td>
                  <td>
                    {{ data.detail.error_code }}
                  </td>
                </tr>
                <tr>
                  <td>
                    Error detail
                  </td>
                  <td>
                    <translate
                      v-if="data.detail.error_code === 'http' && data.detail.status_code"
                      :translate-params="{status: data.detail.status_code}"
                    >
                      The remote server answered with HTTP %{ status }
                    </translate>
                    <translate
                      v-else-if="['http', 'request'].indexOf(data.detail.error_code) > -1"
                    >
                      An HTTP error occurred while contacting the remote server
                    </translate>
                    <translate
                      v-else-if="data.detail.error_code === 'timeout'"
                    >
                      The remote server didn't respond quickly enough
                    </translate>
                    <translate
                      v-else-if="data.detail.error_code === 'connection'"
                    >
                      Impossible to connect to the remote server
                    </translate>
                    <translate
                      v-else-if="['invalid_json', 'invalid_jsonld', 'missing_jsonld_type'].indexOf(data.detail.error_code) > -1"
                    >
                      The remote server returned invalid JSON or JSON-LD data
                    </translate>
                    <translate
                      v-else-if="data.detail.error_code === 'validation'"
                    >
                      Data returned by the remote server had invalid or missing attributes
                    </translate>
                    <translate
                      v-else-if="data.detail.error_code === 'unhandled'"
                    >
                      Unknown error
                    </translate>
                    <translate
                      v-else
                    >
                      Unknown error
                    </translate>
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
            Requesting a fetch…
          </div>
        </div>
        <div
          v-else-if="isPolling"
          class="ui active inverted dimmer"
        >
          <div class="ui text loader">
            Waiting for result…
          </div>
        </div>
        <div
          v-if="errors.length > 0"
          role="alert"
          class="ui negative message"
        >
          <h4 class="header">
            Error while saving settings
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
            Refresh pending
          </h4>
          <p>
            The refresh request hasn't been processed in time by our server. It will be processed later.
          </p>
        </div>
      </div>
      <div class="actions">
        <button class="ui basic cancel button">
          Close
        </button>
        <button
          v-if="data && data.status === 'finished'"
          class="ui confirm success button"
          @click.prevent="showModal = false; emit('refresh')"
        >
          Close and reload page
        </button>
      </div>
    </semantic-modal>
  </div>
</template>
