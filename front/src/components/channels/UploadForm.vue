<script setup lang="ts">
import type { BackendError, Channel, Upload, Track } from '~/types'
import type { VueUploadItem } from 'vue-upload-component'

import { computed, ref, reactive, watchEffect, watch } from 'vue'
import { whenever, useCurrentElement } from '@vueuse/core'
import { humanSize } from '~/utils/filters'
import { useI18n } from 'vue-i18n'
import { useStore } from '~/store'

import axios from 'axios'
import $ from 'jquery'

import UploadMetadataForm from '~/components/channels/UploadMetadataForm.vue'
import FileUploadWidget from '~/components/library/FileUploadWidget.vue'
import LicenseSelect from '~/components/channels/LicenseSelect.vue'
import AlbumSelect from '~/components/channels/AlbumSelect.vue'

import useErrorHandler from '~/composables/useErrorHandler'

interface Events {
  (e: 'status', status: UploadStatus): void
  (e: 'step', step: 1 | 2 | 3): void
}

interface Props {
  channel?: Channel | null
}

interface QuotaStatus {
  remaining: number
}

interface UploadStatus {
  totalSize: number
  totalFiles: number
  progress: number
  speed: number
  quotaStatus: QuotaStatus
  uploadedSize: number
  canSubmit: boolean
}

interface UploadedFile extends VueUploadItem {
  _fileObj?: VueUploadItem
  removed: boolean
  metadata: Metadata
}

const emit = defineEmits<Events>()
const props = withDefaults(defineProps<Props>(), {
  channel: null
})

const { t } = useI18n()
const store = useStore()

const errors = ref([] as string[])

const values = reactive({
  channel: props.channel?.uuid ?? null,
  license: null,
  album: null
})

const files = ref([] as VueUploadItem[])

//
// Channels
//
const availableChannels = reactive({
  channels: [] as Channel[],
  count: 0,
  loading: false
})

const fetchChannels = async () => {
  availableChannels.loading = true

  try {
    const response = await axios.get('channels/', { params: { scope: 'me' } })
    availableChannels.channels = response.data.results
    availableChannels.count = response.data.count
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  availableChannels.loading = false
}

const selectedChannel = computed(() => availableChannels.channels.find((channel) => channel.uuid === values.channel) ?? null)

//
// Quota and space
//
const quotaStatus = ref()
const fetchQuota = async () => {
  try {
    const response = await axios.get('users/me/')
    quotaStatus.value = response.data.quota_status as QuotaStatus
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }
}

const uploadedSize = computed(() => {
  let uploaded = 0

  for (const file of uploadedFiles.value) {
    if (file._fileObj && !file.error) {
      uploaded += (file.size ?? 0) * +(file.progress ?? 0) / 100
    }
  }

  return uploaded
})

const remainingSpace = computed(() => Math.max(
  (quotaStatus.value?.remaining ?? 0) - uploadedSize.value / 1e6,
  0
))

//
// Draft uploads
//
const includeDraftUploads = ref()
const draftUploads = ref([] as Upload[])
whenever(() => values.channel !== null, async () => {
  files.value = []
  draftUploads.value = []

  try {
    const response = await axios.get('uploads', {
      params: { import_status: 'draft', channel: values.channel }
    })

    draftUploads.value = response.data.results as Upload[]
    for (const upload of response.data.results as Upload[]) {
      // @ts-expect-error TODO (wvffle): Resolve type errors when API client is done
      uploadImportData[upload.uuid] = upload.import_metadata ?? {}
    }
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }
}, { immediate: true })

//
// Uploading files
//
const upload = ref()
const beforeFileUpload = (newFile: VueUploadItem) => {
  if (!newFile) return
  if (remainingSpace.value < (newFile.size ?? Infinity) / 1e6) {
    newFile.error = 'denied'
  } else {
    newFile.active = true
  }
}

const baseImportMetadata = computed(() => ({
  channel: values.channel,
  import_status: 'draft',
  import_metadata: { license: values.license, album: values.album }
}))

//
// Uploaded files
//
const removed = reactive(new Set<string>())
const uploadedFiles = computed(() => {
  const uploadedFiles = files.value.map(file => {
    const data = {
      ...file,
      _fileObj: file,
      removed: false,
      metadata: {}
    } as UploadedFile

    if (file.response?.uuid) {
      const uuid = file.response.uuid as string
      data.metadata = uploadImportData[uuid] ?? uploadData[uuid]?.import_metadata ?? {}
      data.removed = removed.has(uuid)
    }

    return data
  })

  if (includeDraftUploads.value) {
    // We have two different objects: draft uploads (so already uploaded in a previous)
    // session, and files uploaded in the current session
    // so we ensure we have a similar structure for both.
    uploadedFiles.unshift(...draftUploads.value.map(upload => ({
      id: upload.uuid,
      response: upload,
      __filename: null,
      size: upload.size,
      progress: '100.00',
      name: upload.source?.replace('upload://', '') ?? '',
      active: false,
      removed: removed.has(upload.uuid),
      metadata: uploadImportData[upload.uuid] ?? audioMetadata[upload.uuid] ?? upload.import_metadata ?? {}
    } as UploadedFile)))
  }

  return uploadedFiles.filter(file => !file.removed) as UploadedFile[]
})

const uploadedFilesById = computed(() => uploadedFiles.value.reduce((acc: Record<string, VueUploadItem>, file) => {
  acc[file.response?.uuid] = file
  return acc
}, {}))

//
// Metadata
//
type Metadata = Pick<Track, 'title' | 'position' | 'tags'> & { cover: string | null, description: string }
const uploadImportData = reactive({} as Record<string, Metadata>)
const audioMetadata = reactive({} as Record<string, Record<string, string>>)
const uploadData = reactive({} as Record<string, { import_metadata: Metadata }>)
const patchUpload = async (id: string, data: Record<string, Metadata>) => {
  const response = await axios.patch(`uploads/${id}/`, data)
  uploadData[id] = response.data
  uploadImportData[id] = response.data.import_metadata
}

const fetchAudioMetadata = async (uuid: string) => {
  delete audioMetadata[uuid]

  const response = await axios.get(`uploads/${uuid}/audio-file-metadata/`)
  audioMetadata[uuid] = response.data

  const uploadedFile = uploadedFilesById.value[uuid]
  if (uploadedFile.response?.import_metadata.title === uploadedFile._fileObj?.name.replace(/\.[^/.]+$/, '') && response.data.title) {
    // Replace existing title deduced from file by the one in audio file metadata, if any
    uploadImportData[uuid].title = response.data.title
  }

  for (const key of ['title', 'position', 'tags'] as const) {
    if (uploadImportData[uuid][key] === undefined) {
      uploadImportData[uuid][key] = response.data[key] as never
    }
  }

  if (uploadImportData[uuid].description === undefined) {
    uploadImportData[uuid].description = (response.data.description ?? {}).text
  }

  await patchUpload(uuid, { import_metadata: uploadImportData[uuid] })
}

watchEffect(async () => {
  for (const file of files.value) {
    if (file.response?.uuid && audioMetadata[file.response.uuid] === undefined) {
      uploadData[file.response.uuid] = file.response as { import_metadata: Metadata }
      uploadImportData[file.response.uuid] = file.response.import_metadata
      fetchAudioMetadata(file.response.uuid)
    }
  }
})

//
// Select upload
//
const selectedUploadId = ref()
const selectedUpload = computed(() => {
  if (!selectedUploadId.value) return null

  const selected = uploadedFiles.value.find(file => file.response?.uuid === selectedUploadId.value)
  if (!selected) return null

  return {
    ...(selected.response ?? {}),
    _fileObj: selected._fileObj
  } as Upload & { _fileObj?: VueUploadItem }
})

//
// Actions
//
const remove = async (file: VueUploadItem) => {
  if (file.response?.uuid) {
    removed.add(file.response.uuid)
    try {
      await axios.delete(`uploads/${file.response.uuid}/`)
    } catch (error) {
      useErrorHandler(error as Error)
    }
  } else {
    upload.value.remove(file)
  }
}

const retry = async (file: VueUploadItem) => {
  upload.value.update(file, { error: '', progress: '0.00' })
  upload.value.active = true
}

//
// Init
//
fetchChannels()
fetchQuota()

//
// Dropdown
//
const el = useCurrentElement()
watch(() => availableChannels.channels, () => {
  $(el.value).find('#channel-dropdown').dropdown({
    onChange (value) {
      values.channel = value
    },
    values: availableChannels.channels.map((channel) => {
      const value = {
        name: channel.artist?.name ?? '',
        value: channel.uuid,
        selected: props.channel?.uuid === channel.uuid
      } as {
        name: string
        value: string
        selected: boolean
        image?: string
        imageClass?: string
        icon?: string
        iconClass?: string
      }

      if (channel.artist?.cover?.urls.medium_square_crop) {
        value.image = store.getters['instance/absoluteUrl'](channel.artist.cover.urls.medium_square_crop)
        value.imageClass = channel.artist.content_category !== 'podcast'
          ? 'ui image avatar'
          : 'ui image'
      } else {
        value.icon = 'user'
        value.iconClass = channel.artist?.content_category !== 'podcast'
          ? 'circular icon'
          : 'bordered icon'
      }

      return value
    })
  })

  $(el.value).find('#channel-dropdown').dropdown('hide')
})

//
// Step
//
const step = ref<1 | 2 | 3>(1)
watchEffect(() => {
  emit('step', step.value)

  if (step.value === 2) {
    selectedUploadId.value = null
  }
})

watch(selectedUploadId, async (to, from) => {
  if (to) {
    step.value = 3
  }

  if (!to && step.value !== 2) {
    step.value = 2
  }

  if (from) {
    await patchUpload(from, { import_metadata: uploadImportData[from] })
  }
})

//
// Status
//

watchEffect(() => {
  const uploaded = uploadedFiles.value
  const totalSize = uploaded.reduce(
    (acc, uploadedFile) => !uploadedFile.error
      ? acc + (uploadedFile.size ?? 0)
      : acc,
    0
  )

  const activeFile = files.value.find(file => file.active)

  emit('status', {
    totalSize,
    totalFiles: uploaded.length,
    progress: Math.floor(uploadedSize.value / totalSize * 100),
    speed: activeFile?.speed ?? 0,
    quotaStatus: quotaStatus.value,
    uploadedSize: uploadedSize.value,
    canSubmit: activeFile !== undefined && uploadedFiles.value.length > 0
  })
})

const labels = computed(() => ({
  editTitle: t('components.channels.UploadForm.button.edit')
}))

const isLoading = ref(false)
const publish = async () => {
  isLoading.value = true

  errors.value = []

  try {
    await axios.post('uploads/action/', {
      action: 'publish',
      objects: uploadedFiles.value.map((file) => file.response?.uuid)
    })

    store.commit('channels/publish', {
      uploads: uploadedFiles.value.map((file) => ({ ...file.response, import_status: 'pending' })),
      channel: selectedChannel.value
    })
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}

defineExpose({
  step,
  publish
})
</script>

<template>
  <form
    :class="['ui', { loading: availableChannels.loading }, 'form component-file-upload']"
    @submit.stop.prevent
  >
    <div
      v-if="errors.length > 0"
      role="alert"
      class="ui negative message"
    >
      <h4 class="header">
        {{ $t('components.channels.UploadForm.header.error') }}
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
    <div :class="['ui', 'required', {hidden: step > 1}, 'field']">
      <label for="channel-dropdown">
        {{ $t('components.channels.UploadForm.label.channel') }}
      </label>
      <div
        id="channel-dropdown"
        class="ui search normal selection dropdown"
      >
        <div class="text" />
        <i class="dropdown icon" />
      </div>
    </div>
    <album-select
      v-model.number="values.album"
      :channel="selectedChannel"
      :class="['ui', {hidden: step > 1}, 'field']"
    />
    <license-select
      v-model="values.license"
      :class="['ui', {hidden: step > 1}, 'field']"
    />
    <div :class="['ui', {hidden: step > 1}, 'message']">
      <div class="content">
        <p>
          <i class="copyright icon" />
          {{ $t('components.channels.UploadForm.help.license') }}
        </p>
      </div>
    </div>
    <template v-if="step === 2 || step === 3">
      <div
        v-if="remainingSpace === 0"
        role="alert"
        class="ui warning message"
      >
        <div class="content">
          <p>
            <i class="warning icon" />
            {{ $t('components.channels.UploadForm.warning.quota') }}
          </p>
        </div>
      </div>
      <template v-else>
        <div
          v-if="step === 2 && draftUploads?.length > 0 && includeDraftUploads === undefined"
          class="ui visible info message"
        >
          <p>
            <i class="redo icon" />
            {{ $t('components.channels.UploadForm.message.pending') }}
          </p>
          <button
            class="ui basic button"
            @click.stop.prevent="includeDraftUploads = false"
          >
            {{ $t('components.channels.UploadForm.button.ignore') }}
          </button>
          <button
            class="ui basic button"
            @click.stop.prevent="includeDraftUploads = true"
          >
            {{ $t('components.channels.UploadForm.button.resume') }}
          </button>
        </div>
        <div
          v-if="uploadedFiles.length > 0"
          :class="[{hidden: step === 3}]"
        >
          <div
            v-for="file in uploadedFiles"
            :key="file.id"
            class="channel-file"
          >
            <div class="content">
              <div
                v-if="file.response?.uuid"
                role="button"
                class="ui basic icon button"
                :title="labels.editTitle"
                @click.stop.prevent="selectedUploadId = file.response?.uuid"
              >
                <i class="pencil icon" />
              </div>
              <div
                v-if="file.error"
                class="ui basic danger icon label"
                :title="file.error.toString()"
                @click.stop.prevent="selectedUploadId = file.response?.uuid"
              >
                <i class="warning sign icon" />
              </div>
              <div
                v-else-if="file.active && !file.response"
                class="ui active slow inline loader"
              />
            </div>
            <h4 class="ui header">
              <template v-if="file.metadata.title">
                {{ file.metadata.title }}
              </template>
              <template v-else>
                {{ file.name }}
              </template>
              <div class="sub header">
                <template v-if="file.response?.uuid">
                  {{ humanSize(file.size ?? 0) }}
                  <template v-if="file.response.duration">
                    <span class="middle middledot symbol" />
                    <human-duration :duration="file.response.duration" />
                  </template>
                </template>
                <template v-else>
                  <span v-if="file.active">
                    {{ $t('components.channels.UploadForm.status.uploading') }}
                  </span>
                  <span v-else-if="file.error">
                    {{ $t('components.channels.UploadForm.status.errored') }}
                  </span>
                  <span v-else>
                    {{ $t('components.channels.UploadForm.status.pending') }}
                  </span>
                  <span class="middle middledot symbol" />
                  {{ humanSize(file.size ?? 0) }}
                  <span class="middle middledot symbol" />
                  {{ parseFloat(file.progress ?? '0') }}
                  <span class="percent symbol" />
                </template>
                <span class="middle middledot symbol" />
                <a @click.stop.prevent="remove(file)">
                  {{ $t('components.channels.UploadForm.button.remove') }}
                </a>
                <template v-if="file.error">
                  <span class="middle middledot symbol" />
                  <a @click.stop.prevent="retry(file)">
                    {{ $t('components.channels.UploadForm.button.retry') }}
                  </a>
                </template>
              </div>
            </h4>
          </div>
        </div>
        <upload-metadata-form
          v-if="selectedUpload"
          v-model:values="uploadImportData[selectedUploadId]"
          :upload="selectedUpload"
        />
        <div
          v-if="step === 2"
          class="ui message"
        >
          <div class="content">
            <p>
              <i class="info icon" />
              {{ $t('components.channels.UploadForm.description.extensions', {extensions: $store.state.ui.supportedExtensions.join(', ')}) }}
            </p>
          </div>
        </div>
        <file-upload-widget
          ref="upload"
          v-model="files"
          :class="['ui', 'icon', 'basic', 'button', 'channels', {hidden: step === 3}]"
          :data="baseImportMetadata"
          @input-file="beforeFileUpload"
        >
          <div>
            <i class="upload icon" />&nbsp;
            {{ $t('components.channels.UploadForm.message.dragAndDrop') }}
          </div>
          <div class="ui very small divider" />
          <div>
            {{ $t('components.channels.UploadForm.label.openBrowser') }}
          </div>
        </file-upload-widget>
        <div class="ui hidden divider" />
      </template>
    </template>
  </form>
</template>
