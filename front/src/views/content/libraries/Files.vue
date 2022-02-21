<template>
  <section class="ui vertical aligned stripe segment">
    <library-files-table :default-query="query" />
  </section>
</template>

<script>
import LibraryFilesTable from './FilesTable.vue'

export default {
  components: {
    LibraryFilesTable
  },
  props: { query: { type: String, required: true } }
}
</script>
