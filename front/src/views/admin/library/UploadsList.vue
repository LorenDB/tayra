<template>
  <main v-title="labels.title">
    <section class="ui vertical stripe segment">
      <h2 class="ui header">
        {{ labels.title }}
      </h2>
      <div class="ui hidden divider" />
      <uploads-table
        :update-url="true"
        :default-query="defaultQuery"
      />
    </section>
  </main>
</template>

<script>
import UploadsTable from '~/components/manage/library/UploadsTable.vue'

export default {
  components: {
    UploadsTable
  },
  props: {
    defaultQuery: { type: String, required: false, default: '' }
  },
  computed: {
    labels () {
      return {
        title: this.$pgettext('*/*/*', 'Uploads')
      }
    }
  }
}
</script>
