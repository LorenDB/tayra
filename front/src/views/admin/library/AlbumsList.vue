<template>
  <main v-title="labels.title">
    <section class="ui vertical stripe segment">
      <h2 class="ui header">
        {{ labels.title }}
      </h2>
      <div class="ui hidden divider" />
      <albums-table
        :update-url="true"
        :default-query="defaultQuery"
      />
    </section>
  </main>
</template>

<script>
import AlbumsTable from '~/components/manage/library/AlbumsTable.vue'

export default {
  components: {
    AlbumsTable
  },
  props: {
    defaultQuery: { type: String, required: false, default: '' }
  },
  computed: {
    labels () {
      return {
        title: this.$pgettext('*/*/*', 'Albums')
      }
    }
  }
}
</script>
