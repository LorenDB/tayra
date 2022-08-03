<script setup lang="ts">
import type { VueUploadItem } from 'vue-upload-component'

import { useCookies } from '@vueuse/integrations/useCookies'
import { computed, ref, watch, getCurrentInstance } from 'vue'
import { useStore } from '~/store'

import FileUpload from 'vue-upload-component'

const { get } = useCookies()
const instance = getCurrentInstance()
const attrs = instance?.attrs ?? {}

const store = useStore()
const headers = computed(() => {
  const headers: Record<string, string> = typeof attrs.headers === 'object'
    ? { ...attrs.headers }
    : {}

  if (store.state.auth.oauth.accessToken) {
    headers.Authorization ??= store.getters['auth/header']
  }

  const csrf = get('csrftoken')
  if (csrf) headers['X-CSRFToken'] = csrf

  return headers
})

const patchFileData = (file: VueUploadItem, data: Record<string, unknown> = {}) => {
  let metadata = data.import_metadata as Record<string, unknown>

  // @ts-expect-error Taken from 3.1.2
  const filename: string = file.file.name || file.file.filename || file.name
  data.source = `upload://${filename}`

  if (metadata) {
    metadata = { ...metadata }
    if (data.channel && !metadata.title) {
      metadata.title = filename.replace(/\.[^/.]+$/, '')
    }

    data.import_metadata = JSON.stringify(metadata)
  }

  return data
}

const uploadAction = async (file: VueUploadItem, self: any): Promise<VueUploadItem> => {
  file.data = patchFileData(file, file.data)

  // NOTE: We're only patching the file data. The rest of the process should remain the same:
  // https://github.com/lian-yue/vue-upload-component/blob/1bd3be3a56e8ed2934dbe0beae151e9026ca51f9/src/FileUpload.vue#L973-L987
  if (self.features.html5) {
    if (self.shouldUseChunkUpload(file)) return self.uploadChunk(file)
    if (file.putAction) return self.uploadPut(file)
    if (file.postAction) return self.uploadHtml5(file)
  }

  if (file.postAction) return self.uploadHtml4(file)
  return Promise.reject(new Error('No action configured'))
}

// NOTE: We need to expose the data and methods that we use
const upload = ref()

const active = ref(false)
watch(active, () => (upload.value.active = active.value))

const update = (file: VueUploadItem, data: Partial<VueUploadItem>) => upload.value.update(file, data)
const remove = (file: VueUploadItem) => upload.value.remove(file)

defineExpose({
  active,
  update,
  remove
})
</script>

<script lang="ts">
// NOTE: We're disallowing overriding `custom-action` and `headers` props
export default { inheritAttrs: false }
</script>

<template>
  <!-- <component
    ref="fileUpload"
    :is="FileUpload"
  >
    <slot />
  </component> -->
  <file-upload
    ref="upload"
    v-bind="$attrs"
    :custom-action="uploadAction"
    :headers="headers"
  >
    <slot />
  </file-upload>
</template>
