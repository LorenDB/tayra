<template>
  <form
    class="ui form"
    @submit.prevent="scan"
  >
    <div
      v-if="errors.length > 0"
      role="alert"
      class="ui negative message"
    >
      <h4 class="header">
        <translate translate-context="Content/Library/Error message.Title">
          Could not fetch remote library
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
    <div class="ui field">
      <label for="library-search"><translate translate-context="Content/Library/Input.Label/Verb">Search a remote library</translate></label>
      <div :class="['ui', 'action', {loading: isLoading}, 'input']">
        <input
          id="library-search"
          v-model="query"
          name="url"
          :placeholder="labels.placeholder"
          type="url"
        >
        <button
          :aria-label="labels.submitLibrarySearch"
          type="submit"
          :class="['ui', 'icon', {loading: isLoading}, 'button']"
        >
          <i class="search icon" />
        </button>
      </div>
    </div>
  </form>
</template>
<script>
import axios from 'axios'

export default {
  data () {
    return {
      query: '',
      isLoading: false,
      errors: []
    }
  },
  computed: {
    labels () {
      return {
        placeholder: this.$pgettext('Content/Library/Input.Placeholder', 'Enter a library URL'),
        submitLibrarySearch: this.$pgettext('Content/Library/Input.Label', 'Submit search')
      }
    }
  },
  methods: {
    scan () {
      if (!this.query) {
        return
      }
      const self = this
      self.errors = []
      self.isLoading = true
      axios.post('federation/libraries/fetch/', { fid: this.query }).then((response) => {
        self.$emit('scanned', response.data)
        self.isLoading = false
      }, error => {
        self.isLoading = false
        self.errors = error.backendErrors
      })
    }
  }
}
</script>
