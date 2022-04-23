<template>
  <section :class="['ui', 'vertical', 'stripe', {loading: isLoading}, 'segment']">
    <div class="ui text container">
      <edit-card
        v-if="obj"
        :obj="obj"
        :current-state="currentState"
      />
    </div>
  </section>
</template>

<script>
import axios from 'axios'
import edits from '~/edits.js'
import EditCard from '~/components/library/EditCard.vue'
export default {
  components: {
    EditCard
  },
  props: {
    object: { type: Object, required: true },
    objectType: { type: String, required: true },
    editId: { type: Number, required: true }
  },
  data () {
    return {
      isLoading: true,
      obj: null
    }
  },
  computed: {
    configs: edits.getConfigs,
    config: edits.getConfig,
    currentState () {
      const self = this
      const s = {}
      this.config.fields.forEach(f => {
        s[f.id] = { value: f.getValue(self.object) }
      })
      return s
    }
  },
  created () {
    this.fetchData()
  },
  methods: {
    fetchData () {
      const self = this
      this.isLoading = true
      axios.get(`mutations/${this.editId}/`).then(response => {
        self.obj = response.data
        self.isLoading = false
      })
    }
  }
}
</script>
