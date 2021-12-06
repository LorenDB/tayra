<template>
  <form
    :class="['ui', {loading: isLoading}, 'form']"
    @submit.stop.prevent
  >
    <div
      v-if="errors.length > 0"
      role="alert"
      class="ui negative message"
    >
      <h4 class="header">
        <translate translate-context="Content/*/Error message.Title">
          Error while creating
        </translate>
      </h4>
      <ul class="list">
        <li
          v-for="(error, key) in errors"
          :key="key"
        >
          {{ error }}
        </li>
      </ul>
    </div>
    <div class="ui required field">
      <label for="album-title">
        <translate translate-context="*/*/*/Noun">Title</translate>
      </label>
      <input
        v-model="values.title"
        type="text"
      >
    </div>
  </form>
</template>
<script>
import axios from 'axios'

export default {
  components: {},
  props: {
    channel: { type: Object, required: true }
  },
  data () {
    return {
      errors: [],
      isLoading: false,
      values: {
        title: ''
      }
    }
  },
  computed: {
    submittable () {
      return this.values.title.length > 0
    }
  },
  watch: {
    submittable (v) {
      this.$emit('submittable', v)
    },
    isLoading (v) {
      this.$emit('loading', v)
    }
  },
  methods: {

    submit () {
      const self = this
      self.isLoading = true
      self.errors = []
      const payload = {
        ...this.values,
        artist: this.channel.artist.id
      }
      return axios.post('albums/', payload).then(
        response => {
          self.isLoading = false
          self.$emit('created')
        },
        error => {
          self.errors = error.backendErrors
          self.isLoading = false
        }
      )
    }
  }
}
</script>
