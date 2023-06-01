<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { computed } from 'vue'

import EditsCardList from '~/components/manage/library/EditsCardList.vue'

interface Props {
  defaultQuery?: string
}

withDefaults(defineProps<Props>(), {
  defaultQuery: ''
})

const { t } = useI18n()
const labels = computed(() => ({
  title: t('views.admin.library.EditsList.title')
}))
</script>

<template>
  <main v-title="labels.title">
    <section class="ui vertical stripe segment">
      <edits-card-list
        :update-url="true"
        :default-query="defaultQuery"
      >
        <h2 class="ui header">
          {{ $t('views.admin.library.EditsList.header.edits') }}
        </h2>
      </edits-card-list>
    </section>
  </main>
</template>
