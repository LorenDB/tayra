<template>
  <div class="ui fluid action input">
    <input
      :id="fieldId"
      required
      name="password"
      :type="passwordInputType"
      :value="value"
      @input="$emit('input', $event.target.value)"
    >
    <button
      type="button"
      :title="labels.title"
      class="ui icon button"
      @click.prevent="showPassword = !showPassword"
    >
      <i class="eye icon" />
    </button>
    <button
      v-if="copyButton"
      type="button"
      class="ui icon button"
      :title="labels.copy"
      @click.prevent="copyPassword"
    >
      <i class="copy icon" />
    </button>
  </div>
</template>
<script>
export default {
  props: {
    value: { type: String, required: true },
    defaultShow: { type: Boolean, default: false },
    copyButton: { type: Boolean, default: false },
    fieldId: { type: String, required: true }
  },
  data () {
    return {
      showPassword: this.defaultShow || false
    }
  },
  computed: {
    labels () {
      return {
        title: this.$pgettext(
          'Content/Settings/Button.Tooltip/Verb',
          'Show/hide password'
        ),
        copy: this.$pgettext('*/*/Button.Label/Short, Verb', 'Copy')
      }
    },
    passwordInputType () {
      if (this.showPassword) {
        return 'text'
      }
      return 'password'
    }
  },
  methods: {
    copyPassword () {
      try {
        this._copyStringToClipboard(this.value)
        this.$store.commit('ui/addMessage', {
          content: this.$pgettext(
            'Content/*/Paragraph',
            'Text copied to clipboard!'
          ),
          date: new Date()
        })
      } catch ($e) {
        console.error('Cannot copy', $e)
      }
    },
    _copyStringToClipboard (str) {
      // cf https://techoverflow.net/2018/03/30/copying-strings-to-the-clipboard-using-pure-javascript/
      const el = document.createElement('textarea')
      el.value = str
      el.setAttribute('readonly', '')
      el.style = { position: 'absolute', left: '-9999px' }
      document.body.appendChild(el)
      el.select()
      document.execCommand('copy')
      document.body.removeChild(el)
    }
  }
}
</script>
