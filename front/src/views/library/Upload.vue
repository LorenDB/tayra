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

<script>

import FileUpload from '~/components/library/FileUpload.vue'

export default {
  components: {
    FileUpload
  },

  beforeRouteLeave (to, from, next) {
    if (this.$refs.fileupload.hasActiveUploads) {
      const answer = window.confirm('This page is asking you to confirm that you want to leave - data you have entered may not be saved.')
      if (answer) {
        next()
      } else {
        next(false)
      }
    } else {
      next()
    }
  },
  props: {
    object: { type: Object, required: true },
    defaultImportReference: { type: String, default: '' }
  }
}
</script>
