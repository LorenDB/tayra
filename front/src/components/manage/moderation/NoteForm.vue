<template>
  <form
    class="ui form"
    @submit.prevent="submit()"
  >
    <div
      v-if="errors.length > 0"
      role="alert"
      class="ui negative message"
    >
      <h4 class="header">
        <translate translate-context="Content/Moderation/Error message.Title">
          Error while submitting note
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
    <div class="field">
      <content-form
        v-model="summary"
        field-id="change-summary"
        :required="true"
        :rows="3"
        :placeholder="labels.summaryPlaceholder"
      />
    </div>
    <button
      :class="['ui', {'loading': isLoading}, 'right', 'floated', 'button']"
      type="submit"
      :disabled="isLoading || null"
    >
      <translate translate-context="Content/Moderation/Button.Label/Verb">
        Add note
      </translate>
    </button>
  </form>
</template>

<script>
import axios from 'axios'
import showdown from 'showdown'

export default {
  props: {
    target: { type: Object, required: true }
  },
  data () {
    return {
      markdown: new showdown.Converter(),
      isLoading: false,
      summary: '',
      errors: []
    }
  },
  computed: {
    labels () {
      return {
        summaryPlaceholder: this.$pgettext('Content/Moderation/Placeholder', 'Describe what actions have been taken, or any other related updates…')
      }
    }
  },
  methods: {
    submit () {
      const self = this
      this.isLoading = true
      const payload = {
        target: this.target,
        summary: this.summary
      }
      this.errors = []
      axios.post('manage/moderation/notes/', payload).then((response) => {
        self.$emit('created', response.data)
        self.summary = ''
        self.isLoading = false
      }, error => {
        self.errors = error.backendErrors
        self.isLoading = false
      })
    }
  }
}
</script>
