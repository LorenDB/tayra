<template>
  <main>
    <div
      v-if="isLoading"
      class="ui vertical segment"
    >
      <div :class="['ui', 'centered', 'active', 'inline', 'loader']" />
    </div>
    <template v-if="object">
      <div class="ui vertical stripe segment">
        <report-card :init-obj="object" />
      </div>
    </template>
  </main>
</template>

<script>
import axios from 'axios'

import ReportCard from '~/components/manage/moderation/ReportCard.vue'

export default {
  components: {
    ReportCard
  },
  props: { id: { type: Number, required: true } },
  data () {
    return {
      isLoading: true,
      object: null
    }
  },
  created () {
    this.fetchData()
  },
  methods: {
    fetchData () {
      const self = this
      this.isLoading = true
      const url = `manage/moderation/reports/${this.id}/`
      axios.get(url).then(response => {
        self.object = response.data
        self.isLoading = false
      })
    }
  }
}
</script>
