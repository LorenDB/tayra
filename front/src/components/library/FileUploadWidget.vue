<script setup lang="ts">
import FileUpload, { VueUploadItem } from 'vue-upload-component'
import { getCookie } from '~/utils'
import { computed, getCurrentInstance } from 'vue'
import { useStore } from '~/store'

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

  const csrf = getCookie('csrftoken')
  if (csrf) headers['X-CSRFToken'] = csrf

  return headers
})

const patchFileData = (file: VueUploadItem, data: Record<string, unknown> = {}) => {
  let metadata = data.import_metadata as Record<string, unknown>

  // @ts-expect-error Taken from vue-upload-component@3.1.2
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
</script>

<script lang="ts">
// NOTE: We're disallowing overriding `custom-action` and `headers` props
export default { inheritAttrs: false }
</script>

<template>
  <file-upload
    v-bind="$attrs"
    :custom-action="uploadAction"
    :headers="headers"
  />
</template>
