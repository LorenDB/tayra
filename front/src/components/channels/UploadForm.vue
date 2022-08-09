<script setup lang="ts">
import type { BackendError, Channel, Upload } from '~/types'
import type { VueUploadItem } from 'vue-upload-component'

import { computed, ref, reactive, watchEffect, watch } from 'vue'
import { whenever, useCurrentElement } from '@vueuse/core'
import { humanSize } from '~/utils/filters'
import { useGettext } from 'vue3-gettext'
import { useStore } from '~/store'

import axios from 'axios'
import $ from 'jquery'

import UploadMetadataForm from '~/components/channels/UploadMetadataForm.vue'
import FileUploadWidget from '~/components/library/FileUploadWidget.vue'
import LicenseSelect from '~/components/channels/LicenseSelect.vue'
import AlbumSelect from '~/components/channels/AlbumSelect.vue'

import useErrorHandler from '~/composables/useErrorHandler'

interface Emits {
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
  metadata: Record<string, string>
}

const emit = defineEmits<Emits>()
const props = withDefaults(defineProps<Props>(), {
  channel: null
})

const { $pgettext } = useGettext()
const store = useStore()

// TODO (wvffle): Find types in UploadMetadataForm.vue
const errors = ref([] as string[])

const values = reactive({
  channel: props.channel?.uuid ?? null,
  license: null,
  album: null
})

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
    upload.value.active = true
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
const files = ref([] as VueUploadItem[])
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
      data.metadata = uploadImportData[uuid] ?? uploadData[uuid].import_metadata ?? {}
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
const uploadImportData = reactive({} as Record<string, Record<string, string>>)
const audioMetadata = reactive({} as Record<string, Record<string, string>>)
const uploadData = reactive({} as Record<string, { import_metadata: Record<string, string> }>)
const patchUpload = async (id: string, data: Record<string, Record<string, string>>) => {
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

  for (const key of ['title', 'position', 'tags']) {
    if (uploadImportData[uuid][key] === undefined) {
      uploadImportData[uuid][key] = response.data[key]
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
      uploadData[file.response.uuid] = file.response as { import_metadata: Record<string, string> }
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
  editTitle: $pgettext('Content/*/Button.Label/Verb', 'Edit')
}))
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
        <translate translate-context="Content/*/Error message.Title">
          Error while publishing
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
    <div :class="['ui', 'required', {hidden: step > 1}, 'field']">
      <label for="channel-dropdown">
        <translate translate-context="*/*/*">Channel</translate>
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
          <translate translate-context="Content/Channels/Popup.Paragraph">
            Add a license to your upload to ensure some freedoms to your public.
          </translate>
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
            <translate translate-context="Content/Library/Paragraph">
              You don't have any space left to upload your files. Please contact the moderators.
            </translate>
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
            <translate translate-context="Popup/Channels/Paragraph">
              You have some draft uploads pending publication.
            </translate>
          </p>
          <button
            class="ui basic button"
            @click.stop.prevent="includeDraftUploads = false"
          >
            <translate translate-context="*/*/*">
              Ignore
            </translate>
          </button>
          <button
            class="ui basic button"
            @click.stop.prevent="includeDraftUploads = true"
          >
            <translate translate-context="*/*/*">
              Resume
            </translate>
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
                v-else-if="file.active"
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
                    · <human-duration :duration="file.response.duration" />
                  </template>
                </template>
                <template v-else>
                  <translate
                    v-if="file.active"
                    translate-context="Channels/*/*"
                  >
                    Uploading
                  </translate>
                  <translate
                    v-else-if="file.error"
                    translate-context="Channels/*/*"
                  >
                    Errored
                  </translate>
                  <translate
                    v-else
                    translate-context="Channels/*/*"
                  >
                    Pending
                  </translate>
                  · {{ humanSize(file.size ?? 0) }}
                  · {{ parseFloat(file.progress ?? '0') }}%
                </template>
                · <a @click.stop.prevent="remove(file)">
                  <translate translate-context="Content/Radio/Button.Label/Verb">Remove</translate>
                </a>
                <template v-if="file.error">
                  ·
                  <a @click.stop.prevent="retry(file)">
                    <translate translate-context="*/*/*">Retry</translate>
                  </a>
                </template>
              </div>
            </h4>
          </div>
        </div>
        <upload-metadata-form
          v-if="selectedUpload"
          :upload="selectedUpload"
          :values="uploadImportData[selectedUploadId]"
          @values="uploadImportData.selectedUploadId = $event"
        />
        <div
          v-if="step === 2"
          class="ui message"
        >
          <div class="content">
            <p>
              <i class="info icon" />
              <translate
                translate-context="Content/Library/Paragraph"
                :translate-params="{extensions: $store.state.ui.supportedExtensions.join(', ')}"
              >
                Supported extensions: %{ extensions }
              </translate>
            </p>
          </div>
        </div>
        <file-upload-widget
          ref="upload"
          v-model="files"
          :class="['ui', 'icon', 'basic', 'button', 'channels', {hidden: step === 3}]"
          :post-action="$store.getters['instance/absoluteUrl']('/api/v1/uploads/')"
          :multiple="true"
          :data="baseImportMetadata"
          :drop="true"
          :extensions="$store.state.ui.supportedExtensions"
          name="audio_file"
          :thread="1"
          @input-file="beforeFileUpload"
        >
          <div>
            <i class="upload icon" />&nbsp;
            <translate translate-context="Content/Channels/Paragraph">
              Drag and drop your files here or open the browser to upload your files
            </translate>
          </div>
          <div class="ui very small divider" />
          <div>
            <translate translate-context="*/*/*">
              Browse…
            </translate>
          </div>
        </file-upload-widget>
        <div class="ui hidden divider" />
      </template>
    </template>
  </form>
</template>
