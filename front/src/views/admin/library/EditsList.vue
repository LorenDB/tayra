<script setup lang="ts">
import { useGettext } from 'vue3-gettext'
import { computed } from 'vue'

import EditsCardList from '~/components/manage/library/EditsCardList.vue'

interface Props {
  defaultQuery?: string
}

withDefaults(defineProps<Props>(), {
  defaultQuery: ''
})

const { $pgettext } = useGettext()
const labels = computed(() => ({
  title: $pgettext('*/Admin/*/Noun', 'Edits')
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
          <translate translate-context="Content/Admin/Title/Noun">
            Library edits
          </translate>
        </h2>
      </edits-card-list>
    </section>
  </main>
</template>
