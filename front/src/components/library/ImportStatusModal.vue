<script setup lang="ts">
import type { Upload } from '~/types'

import SemanticModal from '~/components/semantic/Modal.vue'
import { useVModel } from '@vueuse/core'
import { useI18n } from 'vue-i18n'

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

const { t } = useI18n()

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
      ? t('components.library.ImportStatusModal.error.invalidMetadata.label')
      : t('components.library.ImportStatusModal.error.unknownError.label'),
    detail: errorCode === 'invalid_metadata'
      ? t('components.library.ImportStatusModal.error.invalidMetadata.message')
      : t('components.library.ImportStatusModal.error.unknownError.message'),
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
      {{ $t('components.library.ImportStatusModal.header.importDetail') }}
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
          {{ $t('components.library.ImportStatusModal.message.importDetail') }}
        </div>
        <div
          v-if="upload.import_status === 'finished'"
          class="ui success message"
        >
          {{ $t('components.library.ImportStatusModal.message.importSuccess') }}
        </div>
        <div
          v-if="upload.import_status === 'skipped'"
          role="alert"
          class="ui warning message"
        >
          {{ $t('components.library.ImportStatusModal.warning.importSkipped') }}
        </div>
        <div
          v-if="upload.import_status === 'errored'"
          class="ui error message"
        >
          {{ $t('components.library.ImportStatusModal.error.importFailure') }}
        </div>
        <template v-if="upload.import_status === 'errored'">
          <table class="ui very basic collapsing celled table">
            <tbody>
              <tr>
                <td>
                  {{ $t('components.library.ImportStatusModal.table.error.errorType') }}
                </td>
                <td>
                  {{ getErrorData(upload).label }}
                </td>
              </tr>
              <tr>
                <td>
                  {{ $t('components.library.ImportStatusModal.table.error.errorDetail') }}
                </td>
                <td>
                  {{ getErrorData(upload).detail }}
                  <ul v-if="getErrorData(upload).errorRows.length > 0">
                    <li
                      v-for="row in getErrorData(upload).errorRows"
                      :key="row.key"
                    >
                      {{ row.key }}
                      <span class="left colon symbol" />
                      {{ row.value }}
                    </li>
                  </ul>
                </td>
              </tr>
              <tr>
                <td>
                  {{ $t('components.library.ImportStatusModal.table.error.help') }}
                </td>
                <td>
                  <ul>
                    <li>
                      <a
                        :href="getErrorData(upload).documentationUrl"
                        target="_blank"
                      >
                        {{ $t('components.library.ImportStatusModal.link.documentation') }}
                      </a>
                    </li>
                    <li>
                      <a
                        :href="getErrorData(upload).supportUrl"
                        target="_blank"
                      >
                        {{ $t('components.library.ImportStatusModal.link.support') }}
                      </a>
                    </li>
                  </ul>
                </td>
              </tr>
              <tr>
                <td>
                  {{ $t('components.library.ImportStatusModal.table.error.debug') }}
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
        {{ $t('components.library.ImportStatusModal.button.close') }}
      </button>
    </div>
  </semantic-modal>
</template>
