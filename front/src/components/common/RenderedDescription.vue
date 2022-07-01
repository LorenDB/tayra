<template>
  <div>
    <template v-if="content && !isUpdating">
      <sanitized-html :html="html" />
      <template v-if="isTruncated">
        <div class="ui small hidden divider" />
        <a
          v-if="showMore === false"
          href=""
          @click.stop.prevent="showMore = true"
        >
          <translate translate-context="*/*/Button,Label">Show more</translate>
        </a>
        <a
          v-else
          href=""
          @click.stop.prevent="showMore = false"
        >
          <translate translate-context="*/*/Button,Label">Show less</translate>
        </a>
      </template>
    </template>
    <p v-else-if="!isUpdating">
      <translate translate-context="*/*/Placeholder">
        No description available
      </translate>
    </p>
    <template v-if="!isUpdating && canUpdate && updateUrl">
      <div class="ui hidden divider" />
      <span
        role="button"
        @click="isUpdating = true"
      >
        <i class="pencil icon" />
        <translate translate-context="Content/*/Button.Label/Verb">Edit</translate>
      </span>
    </template>
    <form
      v-if="isUpdating"
      class="ui form"
      @submit.prevent="submit()"
    >
      <div
        v-if="errors.length > 0"
        role="alert"
        class="ui negative message"
      >
        <h4 class="header">
          <translate translate-context="Content/Channels/Error message.Title">
            Error while updating description
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
      <content-form
        v-model="newText"
        :autofocus="true"
      />
      <a
        class="left floated"
        @click.prevent="isUpdating = false"
      >
        <translate translate-context="*/*/Button.Label/Verb">Cancel</translate>
      </a>
      <button
        :class="['ui', {'loading': isLoading}, 'right', 'floated', 'button']"
        type="submit"
        :disabled="isLoading || null"
      >
        <translate translate-context="Content/Channels/Button.Label/Verb">
          Update description
        </translate>
      </button>
      <div class="ui clearing hidden divider" />
    </form>
  </div>
</template>

<script>
import axios from 'axios'
import clip from 'text-clipper'

export default {
  props: {
    content: { type: Object, required: false, default: null },
    fieldName: { type: String, required: false, default: 'description' },
    updateUrl: { required: false, type: String, default: '' },
    canUpdate: { required: false, default: true, type: Boolean },
    fetchHtml: { required: false, default: false, type: Boolean },
    permissive: { required: false, default: false, type: Boolean },
    truncateLength: { required: false, default: 500, type: Number }

  },
  data () {
    return {
      isUpdating: false,
      showMore: false,
      newText: (this.content || { text: '' }).text,
      isLoading: false,
      errors: [],
      preview: null
    }
  },
  computed: {
    html () {
      if (this.fetchHtml) {
        return this.preview
      }
      if (this.truncateLength > 0 && !this.showMore) {
        return this.truncatedHtml
      }
      return this.content.html
    },
    truncatedHtml () {
      return clip(this.content.html, this.truncateLength, { html: true, maxLines: 3 })
    },
    isTruncated () {
      return this.truncateLength > 0 && this.truncatedHtml.length < this.content.html.length
    }
  },
  async created () {
    if (this.fetchHtml) {
      await this.fetchPreview()
    }
  },
  methods: {
    async fetchPreview () {
      const response = await axios.post('text-preview/', { text: this.content.text, permissive: this.permissive })
      this.preview = response.data.rendered
    },
    submit () {
      const self = this
      this.isLoading = true
      this.errors = []
      const payload = {}
      payload[this.fieldName] = null
      if (this.newText) {
        payload[this.fieldName] = {
          content_type: 'text/markdown',
          text: this.newText
        }
      }
      axios.patch(this.updateUrl, payload).then((response) => {
        self.$emit('updated', response.data)
        self.isLoading = false
        self.isUpdating = false
      }, error => {
        self.errors = error.backendErrors
        self.isLoading = false
      })
    }
  }
}
</script>
