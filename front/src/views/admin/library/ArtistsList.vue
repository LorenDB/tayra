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
      />
    </section>
  </main>
</template>

<script>
import ArtistsTable from '~/components/manage/library/ArtistsTable.vue'

export default {
  components: {
    ArtistsTable
  },
  props: {
    defaultQuery: { type: String, required: false, default: '' }
  },
  computed: {
    labels () {
      return {
        title: this.$pgettext('*/*/*/Noun', 'Artists')
      }
    }
  }
}
</script>
