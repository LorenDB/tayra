<template>
  <button
    :class="['ui', {loading: isLoading}, 'button']"
    @click="ajaxCall"
  >
    <slot />
  </button>
</template>
<script>
import axios from 'axios'

export default {
  props: {
    url: { type: String, required: true },
    method: { type: String, required: true }
  },
  data () {
    return {
      isLoading: false
    }
  },
  methods: {
    ajaxCall () {
      const self = this
      this.isLoading = true
      axios[this.method](this.url).then(response => {
        self.$emit('action-done', response.data)
        self.isLoading = false
      }, error => {
        self.isLoading = false
        self.$emit('action-error', error)
      })
    }
  }
}
</script>
