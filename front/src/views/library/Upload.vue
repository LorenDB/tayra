<script setup lang="ts">
import type { Library } from '~/types'

import { onBeforeRouteLeave } from 'vue-router'
import { ref } from 'vue'

import FileUpload from '~/components/library/FileUpload.vue'

interface Props {
  object: Library
  defaultImportReference?: string
}

withDefaults(defineProps<Props>(), {
  defaultImportReference: ''
})

const fileupload = ref()
onBeforeRouteLeave((to, from, next) => {
  if (!fileupload.value.hasActiveUploads) {
    return next()
  }

  const answer = window.confirm('This page is asking you to confirm that you want to leave - data you have entered may not be saved.')
  if (answer) {
    next()
  } else {
    next(false)
  }
})
</script>

<template>
  <section>
    <file-upload
      ref="fileupload"
      :default-import-reference="defaultImportReference"
      :library="object"
      @uploads-finished="$emit('uploads-finished', $event)"
    />
  </section>
</template>
