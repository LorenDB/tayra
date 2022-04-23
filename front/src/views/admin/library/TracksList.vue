<template>
  <main v-title="labels.title">
    <section class="ui vertical stripe segment">
      <h2 class="ui header">
        {{ labels.title }}
      </h2>
      <div class="ui hidden divider" />
      <tracks-table
        :update-url="true"
        :default-query="defaultQuery"
      />
    </section>
  </main>
</template>

<script>
import TracksTable from '~/components/manage/library/TracksTable.vue'

export default {
  components: {
    TracksTable
  },
  props: {
    defaultQuery: { type: String, required: false, default: '' }
  },
  computed: {
    labels () {
      return {
        title: this.$pgettext('*/*/*', 'Tracks')
      }
    }
  }
}
</script>
