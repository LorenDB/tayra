<script setup lang="ts">
import type { BackendError, Library, FileSystem } from '~/types'
import type { VueUploadItem } from 'vue-upload-component'

import { computed, ref, reactive, watch, nextTick } from 'vue'
import { useEventListener, useIntervalFn } from '@vueuse/core'
import { humanSize, truncate } from '~/utils/filters'
import { useI18n } from 'vue-i18n'
import { sortBy } from 'lodash-es'
import { useStore } from '~/store'

import axios from 'axios'

import LibraryFilesTable from '~/views/content/libraries/FilesTable.vue'
import FileUploadWidget from './FileUploadWidget.vue'
import FsBrowser from './FsBrowser.vue'
import FsLogs from './FsLogs.vue'

import useWebSocketHandler from '~/composables/useWebSocketHandler'
import updateQueryString from '~/composables/updateQueryString'
import useErrorHandler from '~/composables/useErrorHandler'

interface Events {
  (e: 'uploads-finished', delta: number):void
}

interface Props {
  library: Library
  defaultImportReference?: string
}

const emit = defineEmits<Events>()
const props = withDefaults(defineProps<Props>(), {
  defaultImportReference: ''
})

const { t } = useI18n()
const store = useStore()

const upload = ref()
const currentTab = ref('uploads')
const supportedExtensions = computed(() => store.state.ui.supportedExtensions)

const labels = computed(() => ({
  tooltips: {
    denied: t('components.library.FileUpload.tooltip.denied'),
    server: t('components.library.FileUpload.tooltip.size'),
    network: t('components.library.FileUpload.tooltip.network'),
    timeout: t('components.library.FileUpload.tooltip.timeout'),
    retry: t('components.library.FileUpload.tooltip.retry'),
    extension: t(
      'components.library.FileUpload.tooltip.extension',
      { extensions: supportedExtensions.value.join(', ') }
    )
  } as Record<string, string>
}))

const uploads = reactive({
  pending: 0,
  finished: 0,
  skipped: 0,
  errored: 0,
  objects: {} as Record<string, any>
})

//
// File counts
//
const files = ref([] as VueUploadItem[])
const processedFilesCount = computed(() => uploads.skipped + uploads.errored + uploads.finished)
const uploadedFilesCount = computed(() => files.value.filter(file => file.success).length)
const retryableFiles = computed(() => files.value.filter(file => file.error))
const erroredFilesCount = computed(() => retryableFiles.value.length)
const processableFiles = computed(() => uploads.pending
  + uploads.skipped
  + uploads.errored
  + uploads.finished
  + uploadedFilesCount.value
)

//
// Uploading
//
const importReference = ref(props.defaultImportReference || new Date().toISOString())
history.replaceState(history.state, '', updateQueryString(location.href, 'import', importReference.value))
const uploadData = computed(() => ({
  library: props.library.uuid,
  import_reference: importReference
}))

watch(() => uploads.finished, (newValue, oldValue) => {
  if (newValue > oldValue) {
    emit('uploads-finished', newValue - oldValue)
  }
})

//
// Upload status
//
const fetchStatus = async () => {
  for (const status of Object.keys(uploads)) {
    if (status === 'objects') continue

    try {
      const response = await axios.get('uploads/', {
        params: {
          import_reference: importReference.value,
          import_status: status,
          page_size: 1
        }
      })

      uploads[status as keyof typeof uploads] = response.data.count
    } catch (error) {
      useErrorHandler(error as Error)
    }
  }
}

fetchStatus()

const needsRefresh = ref(false)
useWebSocketHandler('import.status_updated', async (event) => {
  if (event.upload.import_reference !== importReference.value) {
    return
  }

  // TODO (wvffle): Why?
  await nextTick()

  if (event.new_status === 'errored') {
    for (const file of files.value) {
      if (file.response?.uuid === event.upload.uuid) {
        file.error = event.new_status
        break
      }
    }
  }

  uploads[event.old_status] -= 1
  uploads[event.new_status] += 1
  uploads.objects[event.upload.uuid] = event.upload
  needsRefresh.value = true
})

//
// Files
//
const sortedFiles = computed(() => {
  const filesToSort = files.value

  return [
    ...sortBy(filesToSort.filter(file => file.errored), ['name']),
    ...sortBy(filesToSort.filter(file => !file.errored && !file.success), ['name']),
    ...sortBy(filesToSort.filter(file => file.success), ['name'])
  ]
})

const hasActiveUploads = computed(() => files.value.some(file => file.active))

//
// Quota status
//
const quotaStatus = ref()

const uploadedSize = computed(() => {
  let uploaded = 0

  for (const file of files.value) {
    if (!file.error) {
      uploaded += (file.size ?? 0) * +(file.progress ?? 0) / 100
    }
  }

  return uploaded
})

const remainingSpace = computed(() => Math.max(
  (quotaStatus.value?.remaining ?? 0) - uploadedSize.value / 1e6,
  0
))

watch(remainingSpace, space => {
  if (space <= 0) {
    upload.value.active = false
  }
})

const isLoadingQuota = ref(false)
const fetchQuota = async () => {
  isLoadingQuota.value = true

  try {
    const response = await axios.get('users/me/')
    quotaStatus.value = response.data.quota_status
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoadingQuota.value = false
}

fetchQuota()

//
// Filesystem
//
const fsPath = ref([])
const fsStatus = ref({
  import: {
    status: 'pending'
  }
} as FileSystem)
watch(fsPath, () => fetchFilesystem(true))

const { pause, resume } = useIntervalFn(() => {
  fetchFilesystem(false)
}, 5000, { immediate: false })

const isLoadingFs = ref(false)
const fetchFilesystem = async (updateLoading: boolean) => {
  if (updateLoading) isLoadingFs.value = true
  pause()

  try {
    const response = await axios.get('libraries/fs-import', { params: { path: fsPath.value.join('/') } })
    fsStatus.value = response.data
  } catch (error) {
    useErrorHandler(error as Error)
  }

  if (updateLoading) isLoadingFs.value = false
  if (store.state.auth.availablePermissions.library) resume()
}

if (store.state.auth.availablePermissions.library) {
  fetchFilesystem(true)
}

const fsErrors = ref([] as string[])
const importFs = async () => {
  isLoadingFs.value = true

  try {
    const response = await axios.post('libraries/fs-import', {
      path: fsPath.value.join('/'),
      library: props.library.uuid,
      import_reference: importReference.value
    })

    fsStatus.value = response.data
  } catch (error) {
    fsErrors.value = (error as BackendError).backendErrors
  }

  isLoadingFs.value = false
}

// TODO (wvffle): Maybe use AbortController?
const cancelFsScan = async () => {
  try {
    await axios.delete('libraries/fs-import')
    fetchFilesystem(false)
  } catch (error) {
    useErrorHandler(error as Error)
  }
}

const inputFile = (newFile: VueUploadItem) => {
  if (!newFile) return

  if (remainingSpace.value < (newFile.size ?? Infinity) / 1e6) {
    newFile.error = 'denied'
  } else {
    newFile.active = true
  }
}

// NOTE: For some weird reason typescript thinks that xhr field is not compatible with the same type
const retry = (files: Omit<VueUploadItem, 'xhr'>[]) => {
  for (const file of files) {
    upload.value.update(file, { error: '', progress: '0.00' })
  }

  upload.value.active = true
}

//
// Before unload
//
useEventListener(window, 'beforeunload', (event) => {
  if (!hasActiveUploads.value) return null
  event.preventDefault()
  return (event.returnValue = t('components.library.FileUpload.message.listener'))
})
</script>

<template>
  <div class="component-file-upload">
    <div class="ui top attached tabular menu">
      <a
        href=""
        :class="['item', {active: currentTab === 'uploads'}]"
        @click.prevent="currentTab = 'uploads'"
      >
        {{ $t('components.library.FileUpload.link.uploading') }}
        <div
          v-if="files.length === 0"
          class="ui label"
        >
          {{ $t('components.library.FileUpload.empty.noFiles') }}
        </div>
        <div
          v-else-if="files.length > uploadedFilesCount + erroredFilesCount"
          class="ui warning label"
        >
          {{ uploadedFilesCount + erroredFilesCount }}
          <span class="slash symbol" />
          {{ files.length }}
        </div>
        <div
          v-else
          :class="['ui', {'success': erroredFilesCount === 0}, {'danger': erroredFilesCount > 0}, 'label']"
        >
          {{ uploadedFilesCount + erroredFilesCount }}
          <span class="slash symbol" />
          {{ files.length }}
        </div>
      </a>
      <a
        href=""
        :class="['item', {active: currentTab === 'processing'}]"
        @click.prevent="currentTab = 'processing'"
      >
        {{ $t('components.library.FileUpload.link.processing') }}
        <div
          v-if="processableFiles === 0"
          class="ui label"
        >
          {{ $t('components.library.FileUpload.empty.noFiles') }}
        </div>
        <div
          v-else-if="processableFiles > processedFilesCount"
          class="ui warning label"
        >
          {{ processedFilesCount }}
          <span class="slash symbol" />
          {{ processableFiles }}
        </div>
        <div
          v-else
          :class="['ui', {'success': uploads.errored === 0}, {'danger': uploads.errored > 0}, 'label']"
        >
          {{ processedFilesCount }}
          <span class="slash symbol" />
          {{ processableFiles }}
        </div>
      </a>
    </div>
    <div :class="['ui', 'bottom', 'attached', 'segment', {hidden: currentTab != 'uploads'}]">
      <div :class="['ui', {loading: isLoadingQuota}, 'container']">
        <div :class="['ui', {red: remainingSpace === 0}, {warning: remainingSpace > 0 && remainingSpace <= 50}, 'small', 'statistic']">
          <div class="label">
            {{ $t('components.library.FileUpload.label.remainingSpace') }}
          </div>
          <div class="value">
            {{ humanSize(remainingSpace * 1000 * 1000) }}
          </div>
        </div>
        <div class="ui divider" />
        <h2 class="ui header">
          {{ $t('components.library.FileUpload.header.local') }}
        </h2>
        <div class="ui message">
          <p>
            {{ $t('components.library.FileUpload.message.local.message') }}
          </p>
          <ul>
            <li v-if="library.privacy_level != 'me'">
              {{ $t('components.library.FileUpload.message.local.copyright') }}
            </li>
            <li>
              {{ $t('components.library.FileUpload.message.local.tag') }}&nbsp;
              <a
                href="http://picard.musicbrainz.org/"
                target="_blank"
              >{{ $t('components.library.FileUpload.link.picard') }}</a>
            </li>
            <li>
              {{ $t('components.library.FileUpload.message.local.format') }}
            </li>
          </ul>
        </div>
        <file-upload-widget
          ref="upload"
          v-model="files"
          :class="['ui', 'icon', 'basic', 'button']"
          :data="uploadData"
          @input-file="inputFile"
        >
          <i class="upload icon" />&nbsp;
          {{ $t('components.library.FileUpload.label.uploadWidget') }}
          <br>
          <br>
          <i>
            {{ $t('components.library.FileUpload.label.extensions', {extensions: supportedExtensions.join(', ')}) }}
          </i>
        </file-upload-widget>
      </div>
      <div
        v-if="files.length > 0"
        class="table-wrapper"
      >
        <div class="ui hidden divider" />
        <table class="ui unstackable table">
          <thead>
            <tr>
              <th class="ten wide">
                {{ $t('components.library.FileUpload.table.upload.header.filename') }}
              </th>
              <th>
                {{ $t('components.library.FileUpload.table.upload.header.size') }}
              </th>
              <th>
                {{ $t('components.library.FileUpload.table.upload.header.status') }}
              </th>
              <th>
                {{ $t('components.library.FileUpload.table.upload.header.actions') }}
              </th>
            </tr>
            <tr v-if="retryableFiles.length > 1">
              <th class="ten wide" />
              <th />
              <th />
              <th>
                <button
                  class="ui right floated small basic button"
                  @click.prevent="retry(retryableFiles)"
                >
                  {{ $t('components.library.FileUpload.button.retry') }}
                </button>
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="file in sortedFiles"
              :key="file.id"
            >
              <td :title="file.name">
                {{ truncate(file.name ?? '', 60) }}
              </td>
              <td>{{ humanSize(file.size ?? 0) }}</td>
              <td>
                <span
                  v-if="typeof file.error === 'string' && file.error"
                  class="ui tooltip"
                  :data-tooltip="labels.tooltips[file.error]"
                >
                  <span class="ui danger icon label">
                    <i class="question circle outline icon" /> {{ file.error }}
                  </span>
                </span>
                <span
                  v-else-if="file.success"
                  class="ui success label"
                >
                  <span key="1">
                    {{ $t('components.library.FileUpload.table.upload.status.uploaded') }}
                  </span>
                </span>
                <span
                  v-else-if="file.active"
                  class="ui warning label"
                >
                  <span key="2">
                    {{ $t('components.library.FileUpload.table.upload.status.uploading') }}
                  </span>

                  {{ $t('components.library.FileUpload.table.upload.progress', {percent: parseFloat(file.progress ?? '0.00')}) }}
                </span>
                <span
                  v-else
                  class="ui label"
                >
                  <span key="3">
                    {{ $t('components.library.FileUpload.table.upload.status.pending') }}
                  </span>
                </span>
              </td>
              <td>
                <template v-if="file.error">
                  <button
                    v-if="retryableFiles.includes(file)"
                    class="ui tiny basic icon right floated button"
                    :title="labels.tooltips.retry"
                    @click.prevent="retry([file])"
                  >
                    <i class="redo icon" />
                  </button>
                </template>
                <template v-else-if="!file.success">
                  <button
                    class="ui tiny basic danger icon right floated button"
                    @click.prevent="upload.remove(file)"
                  >
                    <i class="delete icon" />
                  </button>
                </template>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <div class="ui divider" />
      <h2 class="ui header">
        {{ $t('components.library.FileUpload.header.server') }}
      </h2>
      <div
        v-if="fsErrors.length > 0"
        role="alert"
        class="ui negative message"
      >
        <h3 class="header">
          {{ $t('components.library.FileUpload.header.failure') }}
        </h3>
        <ul class="list">
          <li
            v-for="(error, key) in fsErrors"
            :key="key"
          >
            {{ error }}
          </li>
        </ul>
      </div>
      <fs-browser
        v-model="fsPath"
        :loading="isLoadingFs"
        :data="fsStatus"
        @import="importFs"
      />
      <template v-if="fsStatus && fsStatus.import">
        <h3 class="ui header">
          {{ $t('components.library.FileUpload.header.status') }}
        </h3>
        <p v-if="fsStatus.import.reference !== importReference">
          {{ $t('components.library.FileUpload.description.previousImport') }}
        </p>
        <p v-else>
          {{ $t('components.library.FileUpload.description.import') }}
        </p>

        <button
          v-if="fsStatus.import.status === 'started' || fsStatus.import.status === 'pending'"
          class="ui button"
          @click="cancelFsScan"
        >
          {{ $t('components.library.FileUpload.button.cancel') }}
        </button>
        <fs-logs :data="fsStatus.import" />
      </template>
    </div>
    <div :class="['ui', 'bottom', 'attached', 'segment', {hidden: currentTab != 'processing'}]">
      <library-files-table
        :needs-refresh="needsRefresh"
        ordering-config-name="library.detail.upload"
        :filters="{import_reference: importReference}"
        :custom-objects="Object.values(uploads.objects)"
        @fetch-start="needsRefresh = false"
      />
    </div>
  </div>
</template>
