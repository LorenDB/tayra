<script setup lang="ts">
import type { VueUploadItem } from 'vue-upload-component'
import type { BackendError, Library, FileSystem } from '~/types'

import { computed, ref, reactive, watch, nextTick } from 'vue'
import { useEventListener, useIntervalFn } from '@vueuse/core'
import { humanSize, truncate } from '~/utils/filters'
import { useGettext } from 'vue3-gettext'
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

const { $pgettext } = useGettext()
const store = useStore()

const upload = ref()
const currentTab = ref('uploads')
const supportedExtensions = computed(() => store.state.ui.supportedExtensions)

const labels = computed(() => ({
  tooltips: {
    denied: $pgettext('Content/Library/Help text', 'Upload denied, ensure the file is not too big and that you have not reached your quota'),
    server: $pgettext('Content/Library/Help text', 'Cannot upload this file, ensure it is not too big'),
    network: $pgettext('Content/Library/Help text', 'A network error occurred while uploading this file'),
    timeout: $pgettext('Content/Library/Help text', 'Upload timeout, please try again'),
    retry: $pgettext('*/*/*/Verb', 'Retry'),
    extension: $pgettext(
      'Content/Library/Help text',
      'Invalid file type, ensure you are uploading an audio file. Supported file extensions are %{ extensions }',
      { extensions: supportedExtensions.value.join(', ') }
    )
  }
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
const fsPath = reactive([])
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
    const response = await axios.get('libraries/fs-import', { params: { path: fsPath.join('/') } })
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
      path: fsPath.join('/'),
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
    upload.value.active = true
  }
}

const retry = (files: VueUploadItem[]) => {
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
  return (event.returnValue = $pgettext('*/*/*', 'This page is asking you to confirm that you want to leave - data you have entered may not be saved.'))
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
        <translate translate-context="Content/Library/Tab.Title/Short">Uploading</translate>
        <div
          v-if="files.length === 0"
          class="ui label"
        >
          0
        </div>
        <div
          v-else-if="files.length > uploadedFilesCount + erroredFilesCount"
          class="ui warning label"
        >
          {{ uploadedFilesCount + erroredFilesCount }}/{{ files.length }}
        </div>
        <div
          v-else
          :class="['ui', {'success': erroredFilesCount === 0}, {'danger': erroredFilesCount > 0}, 'label']"
        >
          {{ uploadedFilesCount + erroredFilesCount }}/{{ files.length }}
        </div>
      </a>
      <a
        href=""
        :class="['item', {active: currentTab === 'processing'}]"
        @click.prevent="currentTab = 'processing'"
      >
        <translate translate-context="Content/Library/Tab.Title/Short">Processing</translate>
        <div
          v-if="processableFiles === 0"
          class="ui label"
        >
          0
        </div>
        <div
          v-else-if="processableFiles > processedFilesCount"
          class="ui warning label"
        >
          {{ processedFilesCount }}/{{ processableFiles }}
        </div>
        <div
          v-else
          :class="['ui', {'success': uploads.errored === 0}, {'danger': uploads.errored > 0}, 'label']"
        >
          {{ processedFilesCount }}/{{ processableFiles }}
        </div>
      </a>
    </div>
    <div :class="['ui', 'bottom', 'attached', 'segment', {hidden: currentTab != 'uploads'}]">
      <div :class="['ui', {loading: isLoadingQuota}, 'container']">
        <div :class="['ui', {red: remainingSpace === 0}, {warning: remainingSpace > 0 && remainingSpace <= 50}, 'small', 'statistic']">
          <div class="label">
            <translate translate-context="Content/Library/Paragraph">
              Remaining storage space
            </translate>
          </div>
          <div class="value">
            {{ humanSize(remainingSpace * 1000 * 1000) }}
          </div>
        </div>
        <div class="ui divider" />
        <h2 class="ui header">
          <translate translate-context="Content/Library/Title/Verb">
            Upload music from '~/your local storage
          </translate>
        </h2>
        <div class="ui message">
          <p>
            <translate translate-context="Content/Library/Paragraph">
              You are about to upload music to your library. Before proceeding, please ensure that:
            </translate>
          </p>
          <ul>
            <li v-if="library.privacy_level != 'me'">
              <translate translate-context="Content/Library/List item">
                You are not uploading copyrighted content in a public library, otherwise you may be infringing the law
              </translate>
            </li>
            <li>
              <translate translate-context="Content/Library/List item">
                The music files you are uploading are tagged properly.
              </translate>&nbsp;
              <a
                href="http://picard.musicbrainz.org/"
                target="_blank"
              ><translate translate-context="Content/Library/Link">We recommend using Picard for that purpose.</translate></a>
            </li>
            <li>
              <translate translate-context="Content/Library/List item">
                The music files you are uploading are in OGG, Flac, MP3 or AIFF format
              </translate>
            </li>
          </ul>
        </div>
        <file-upload-widget
          ref="upload"
          v-model="files"
          :class="['ui', 'icon', 'basic', 'button']"
          :post-action="$store.getters['instance/absoluteUrl']('/api/v1/uploads/')"
          :multiple="true"
          :data="uploadData"
          :drop="true"
          :extensions="supportedExtensions"
          name="audio_file"
          :thread="1"
          @input-file="inputFile"
        >
          <i class="upload icon" />&nbsp;
          <translate translate-context="Content/Library/Paragraph/Call to action">
            Click to select files to upload or drag and drop files or directories
          </translate>
          <br>
          <br>
          <i>
            <translate
              translate-context="Content/Library/Paragraph"
              :translate-params="{extensions: supportedExtensions.join(', ')}"
            >
              Supported extensions: %{ extensions }
            </translate>
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
                <translate translate-context="Content/Library/Table.Label">
                  Filename
                </translate>
              </th>
              <th>
                <translate translate-context="Content/*/*/Noun">
                  Size
                </translate>
              </th>
              <th>
                <translate translate-context="*/*/*">
                  Status
                </translate>
              </th>
              <th>
                <translate translate-context="*/*/*">
                  Actions
                </translate>
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
                  <translate translate-context="Content/Library/Table">
                    Retry failed uploads
                  </translate>
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
                  :data-tooltip="labels.tooltips[file.error as keyof typeof labels.tooltips]"
                >
                  <span class="ui danger icon label">
                    <i class="question circle outline icon" /> {{ file.error }}
                  </span>
                </span>
                <span
                  v-else-if="file.success"
                  class="ui success label"
                >
                  <translate
                    key="1"
                    translate-context="Content/Library/Table"
                  >Uploaded</translate>
                </span>
                <span
                  v-else-if="file.active"
                  class="ui warning label"
                >
                  <translate
                    key="2"
                    translate-context="Content/Library/Table"
                  >
                    Uploading…
                  </translate>
                  ({{ parseFloat(file.progress ?? '0.00') }}%)
                </span>
                <span
                  v-else
                  class="ui label"
                >
                  <translate
                    key="3"
                    translate-context="Content/Library/*/Short"
                  >
                    Pending
                  </translate>
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
        <translate translate-context="Content/Library/Title/Verb">
          Import music from your server
        </translate>
      </h2>
      <div
        v-if="fsErrors.length > 0"
        role="alert"
        class="ui negative message"
      >
        <h3 class="header">
          <translate translate-context="Content/*/Error message.Title">
            Error while launching import
          </translate>
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
          <translate translate-context="Content/Library/Title/Verb">
            Import status
          </translate>
        </h3>
        <p v-if="fsStatus.import.reference !== importReference">
          <translate translate-context="Content/Library/Paragraph">
            Results of your previous import:
          </translate>
        </p>
        <p v-else>
          <translate translate-context="Content/Library/Paragraph">
            Results of your import:
          </translate>
        </p>

        <button
          v-if="fsStatus.import.status === 'started' || fsStatus.import.status === 'pending'"
          class="ui button"
          @click="cancelFsScan"
        >
          <translate translate-context="*/*/Button.Label/Verb">
            Cancel
          </translate>
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
