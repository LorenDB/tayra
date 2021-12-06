<template>
  <div class="ui fluid action input component-copy-input">
    <p
      v-if="copied"
      class="message"
    >
      <translate translate-context="Content/*/Paragraph">
        Text copied to clipboard!
      </translate>
    </p>
    <input
      :id="id"
      ref="input"
      :name="id"
      :value="value"
      type="text"
      readonly
    >
    <button
      :class="['ui', buttonClasses, 'right', 'labeled', 'icon', 'button']"
      @click="copy"
    >
      <i class="copy icon" />
      <translate translate-context="*/*/Button.Label/Short, Verb">
        Copy
      </translate>
    </button>
  </div>
</template>
<script>
export default {
  props: {
    value: { type: String, required: true },
    buttonClasses: { type: String, default: 'accent' },
    id: { type: String, default: 'copy-input' }
  },
  data () {
    return {
      copied: false,
      timeout: null
    }
  },
  methods: {
    copy () {
      if (this.timeout) {
        clearTimeout(this.timeout)
      }
      this.$refs.input.select()
      document.execCommand('Copy')
      const self = this
      self.copied = true
      this.timeout = setTimeout(() => {
        self.copied = false
      }, 5000)
    }
  }
}
</script>
