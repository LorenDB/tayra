<script setup lang="ts">
import LibraryFilesTable from './FilesTable.vue'

interface Props {
  query: string
}

defineProps<Props>()
</script>

<template>
  <section class="ui vertical aligned stripe segment">
    <library-files-table :default-query="query" />
  </section>
</template>
