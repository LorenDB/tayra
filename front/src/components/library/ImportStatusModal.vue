<script setup lang="ts">
import type { Upload } from '~/types'

import SemanticModal from '~/components/semantic/Modal.vue'
import { useVModel } from '@vueuse/core'
import { useGettext } from 'vue3-gettext'

interface ErrorEntry {
  key: string
  value: string
}

interface Events {
  (e: 'update:show', value: boolean): void
}

interface Props {
  upload: Upload
  show: boolean
}

const emit = defineEmits<Events>()
const props = defineProps<Props>()

const show = useVModel(props, 'show', emit)

const getErrors = (details: object): ErrorEntry[] => {
  const errors = []

  for (const [key, value] of Object.entries(details)) {
    if (Array.isArray(value)) {
      errors.push({ key, value: value.join(', ') })
      continue
    }

    if (typeof value === 'object') {
      errors.push(...getErrors(value).map(error => ({
        ...error,
        key: `${key} / ${error.key}`
      })))
    }
  }

  return errors
}

const { $pgettext } = useGettext()

const getErrorData = (upload: Upload) => {
  const payload = upload.import_details ?? { error_code: '', detail: {} }

  const errorCode = payload.error_code
    ? payload.error_code
    : 'unknown_error'

  return {
    errorCode,
    supportUrl: 'https://forum.funkwhale.audio/t/support',
    documentationUrl: `https://docs.funkwhale.audio/users/upload.html#${errorCode}`,
    label: errorCode === 'invalid_metadata'
      ? $pgettext('Popup/Import/Error.Label', 'Invalid metadata')
      : $pgettext('*/*/Error', 'Unknown error'),
    detail: errorCode === 'invalid_metadata'
      ? $pgettext('Popup/Import/Error.Label', 'The metadata included in the file is invalid or some mandatory fields are missing.')
      : $pgettext('Popup/Import/Error.Label', 'An unknown error occurred'),
    errorRows: errorCode === 'invalid_metadata'
      ? getErrors(payload.detail ?? {})
      : [],
    debugInfo: {
      source: upload.source,
      ...payload
    }
  }
}
</script>

<template>
  <semantic-modal v-model:show="show">
    <h4 class="header">
      <translate translate-context="Popup/Import/Title">
        Import detail
      </translate>
    </h4>
    <div
      v-if="Object.keys(upload).length > 0"
      class="content"
    >
      <div class="description">
        <div
          v-if="upload.import_status === 'pending'"
          class="ui message"
        >
          <translate translate-context="Popup/Import/Message">
            Upload is still pending and will soon be processed by the server.
          </translate>
        </div>
        <div
          v-if="upload.import_status === 'finished'"
          class="ui success message"
        >
          <translate translate-context="Popup/Import/Message">
            Upload was successfully processed by the server.
          </translate>
        </div>
        <div
          v-if="upload.import_status === 'skipped'"
          role="alert"
          class="ui warning message"
        >
          <translate translate-context="Popup/Import/Message">
            Upload was skipped because a similar one is already available in one of your libraries.
          </translate>
        </div>
        <div
          v-if="upload.import_status === 'errored'"
          class="ui error message"
        >
          <translate translate-context="Popup/Import/Message">
            An error occurred during upload processing. You will find more information below.
          </translate>
        </div>
        <template v-if="upload.import_status === 'errored'">
          <table class="ui very basic collapsing celled table">
            <tbody>
              <tr>
                <td>
                  <translate translate-context="Popup/Import/Table.Label/Noun">
                    Error type
                  </translate>
                </td>
                <td>
                  {{ getErrorData(upload).label }}
                </td>
              </tr>
              <tr>
                <td>
                  <translate translate-context="Popup/Import/Table.Label/Noun">
                    Error detail
                  </translate>
                </td>
                <td>
                  {{ getErrorData(upload).detail }}
                  <ul v-if="getErrorData(upload).errorRows.length > 0">
                    <li
                      v-for="row in getErrorData(upload).errorRows"
                      :key="row.key"
                    >
                      {{ row.key }}: {{ row.value }}
                    </li>
                  </ul>
                </td>
              </tr>
              <tr>
                <td>
                  <translate translate-context="Footer/*/Link">
                    Getting help
                  </translate>
                </td>
                <td>
                  <ul>
                    <li>
                      <a
                        :href="getErrorData(upload).documentationUrl"
                        target="_blank"
                      >
                        <translate translate-context="Popup/Import/Table.Label/Value">Read our documentation for this error</translate>
                      </a>
                    </li>
                    <li>
                      <a
                        :href="getErrorData(upload).supportUrl"
                        target="_blank"
                      >
                        <translate translate-context="Popup/Import/Table.Label/Value">Open a support thread (include the debug information below in your message)</translate>
                      </a>
                    </li>
                  </ul>
                </td>
              </tr>
              <tr>
                <td>
                  <translate translate-context="Popup/Import/Table.Label/Noun">
                    Debug information
                  </translate>
                </td>
                <td>
                  <div class="ui form">
                    <textarea
                      class="ui textarea"
                      rows="10"
                      :value="JSON.stringify(getErrorData(upload).debugInfo)"
                    />
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </template>
      </div>
    </div>
    <div class="actions">
      <button class="ui deny button">
        <translate translate-context="*/*/Button.Label/Verb">
          Close
        </translate>
      </button>
    </div>
  </semantic-modal>
</template>
