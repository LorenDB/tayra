<script setup lang="ts">
import type { BackendError } from '~/types'

import axios from 'axios'
import SemanticModal from '~/components/semantic/Modal.vue'
import { useTimeoutFn } from '@vueuse/core'
import { ref } from 'vue'

interface Props {
  url: string
}

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
        <translate translate-context="Popup/*/Title">
          Refreshing object from remote server…
        </translate>
      </h3>
      <div class="scrolling content">
        <template v-if="data && data.status != 'pending'">
          <div
            v-if="data.status === 'skipped'"
            class="ui message"
          >
            <h4 class="header">
              <translate translate-context="Popup/*/Message.Title">
                Refresh was skipped
              </translate>
            </h4>
            <p>
              <translate translate-context="Popup/*/Message.Content">
                The remote server answered, but returned data was unsupported by Funkwhale.
              </translate>
            </p>
          </div>
          <div
            v-else-if="data.status === 'finished'"
            class="ui success message"
          >
            <h4 class="header">
              <translate translate-context="Popup/*/Message.Title">
                Refresh successful
              </translate>
            </h4>
            <p>
              <translate translate-context="Popup/*/Message.Content">
                Data was refreshed successfully from remote server.
              </translate>
            </p>
          </div>
          <div
            v-else-if="data.status === 'errored'"
            class="ui error message"
          >
            <h4 class="header">
              <translate translate-context="Popup/*/Message.Title">
                Refresh error
              </translate>
            </h4>
            <p>
              <translate translate-context="Popup/*/Message.Content">
                An error occurred while trying to refresh data:
              </translate>
            </p>
            <table class="ui very basic collapsing celled table">
              <tbody>
                <tr>
                  <td>
                    <translate translate-context="Popup/Import/Table.Label/Noun">
                      Error type
                    </translate>
                  </td>
                  <td>
                    {{ data.detail.error_code }}
                  </td>
                </tr>
                <tr>
                  <td>
                    <translate translate-context="Popup/Import/Table.Label/Noun">
                      Error detail
                    </translate>
                  </td>
                  <td>
                    <translate
                      v-if="data.detail.error_code === 'http' && data.detail.status_code"
                      :translate-params="{status: data.detail.status_code}"
                      translate-context="*/*/Error"
                    >
                      The remote server answered with HTTP %{ status }
                    </translate>
                    <translate
                      v-else-if="['http', 'request'].indexOf(data.detail.error_code) > -1"
                      translate-context="*/*/Error"
                    >
                      An HTTP error occurred while contacting the remote server
                    </translate>
                    <translate
                      v-else-if="data.detail.error_code === 'timeout'"
                      translate-context="*/*/Error"
                    >
                      The remote server didn't respond quickly enough
                    </translate>
                    <translate
                      v-else-if="data.detail.error_code === 'connection'"
                      translate-context="*/*/Error"
                    >
                      Impossible to connect to the remote server
                    </translate>
                    <translate
                      v-else-if="['invalid_json', 'invalid_jsonld', 'missing_jsonld_type'].indexOf(data.detail.error_code) > -1"
                      translate-context="*/*/Error"
                    >
                      The remote server returned invalid JSON or JSON-LD data
                    </translate>
                    <translate
                      v-else-if="data.detail.error_code === 'validation'"
                      translate-context="*/*/Error"
                    >
                      Data returned by the remote server had invalid or missing attributes
                    </translate>
                    <translate
                      v-else-if="data.detail.error_code === 'unhandled'"
                      translate-context="*/*/Error"
                    >
                      Unknown error
                    </translate>
                    <translate
                      v-else
                      translate-context="*/*/Error"
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
            <translate translate-context="Popup/*/Loading.Title">
              Requesting a fetch…
            </translate>
          </div>
        </div>
        <div
          v-else-if="isPolling"
          class="ui active inverted dimmer"
        >
          <div class="ui text loader">
            <translate translate-context="Popup/*/Loading.Title">
              Waiting for result…
            </translate>
          </div>
        </div>
        <div
          v-if="errors.length > 0"
          role="alert"
          class="ui negative message"
        >
          <h4 class="header">
            <translate translate-context="Content/*/Error message.Title">
              Error while saving settings
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
        <div
          v-else-if="data && data.status === 'pending' && pollsCount >= MAX_POLLS"
          role="alert"
          class="ui warning message"
        >
          <h4 class="header">
            <translate translate-context="Popup/*/Message.Title">
              Refresh pending
            </translate>
          </h4>
          <p>
            <translate translate-context="Popup/*/Message.Content">
              The refresh request hasn't been processed in time by our server. It will be processed later.
            </translate>
          </p>
        </div>
      </div>
      <div class="actions">
        <button class="ui basic cancel button">
          <translate translate-context="*/*/Button.Label/Verb">
            Close
          </translate>
        </button>
        <button
          v-if="data && data.status === 'finished'"
          class="ui confirm success button"
          @click.prevent="showModal = false; $emit('refresh')"
        >
          <translate translate-context="*/*/Button.Label/Verb">
            Close and reload page
          </translate>
        </button>
      </div>
    </semantic-modal>
  </div>
</template>
