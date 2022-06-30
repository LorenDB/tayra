<script setup lang="ts">
import ArtistsTable from '~/components/manage/library/ArtistsTable.vue'
import { useGettext } from 'vue3-gettext'
import { computed } from 'vue'

interface Props {
  defaultQuery?: string
}

withDefaults(defineProps<Props>(), {
  defaultQuery: ''
})

const { $pgettext } = useGettext()
const labels = computed(() => ({
  title: $pgettext('*/*/*/Noun', 'Artists')
}))
</script>

<template>
  <main v-title="labels.title">
    <section class="ui vertical stripe segment">
      <h2 class="ui header">
        {{ labels.title }}
      </h2>
      <div class="ui hidden divider" />

      <artists-table
        :update-url="true"
        :default-query="defaultQuery"
        :ordering-config-name="null"
      />
    </section>
  </main>
</template>
