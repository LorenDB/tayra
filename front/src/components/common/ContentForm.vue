<template>
  <div class="content-form ui segments">
    <div class="ui segment">
      <div class="ui tiny secondary pointing menu">
        <button
          :class="[{active: !isPreviewing}, 'item']"
          @click.prevent="isPreviewing = false"
        >
          <translate translate-context="*/Form/Menu.item">
            Write
          </translate>
        </button>
        <button
          :class="[{active: isPreviewing}, 'item']"
          @click.prevent="isPreviewing = true"
        >
          <translate translate-context="*/Form/Menu.item">
            Preview
          </translate>
        </button>
      </div>
      <template v-if="isPreviewing">
        <div
          v-if="isLoadingPreview"
          class="ui placeholder"
        >
          <div class="paragraph">
            <div class="line" />
            <div class="line" />
            <div class="line" />
            <div class="line" />
          </div>
        </div>
        <p v-else-if="preview === null">
          <translate translate-context="*/Form/Paragraph">
            Nothing to preview.
          </translate>
        </p>
        <div
          v-else
          v-html="preview"
        />
      </template>
      <template v-else>
        <div class="ui transparent input">
          <textarea
            :id="fieldId"
            ref="textarea"
            v-model="newValue"
            :name="fieldId"
            :rows="rows"
            :required="required || null"
            :placeholder="placeholder || labels.placeholder"
          />
        </div>
        <div class="ui very small hidden divider" />
      </template>
    </div>
    <div class="ui bottom attached segment">
      <span
        v-if="charLimit"
        :class="['right', 'floated', {'ui danger text': remainingChars < 0}]"
      >
        {{ remainingChars }}
      </span>
      <p>
        <translate translate-context="*/Form/Paragraph">
          Markdown syntax is supported.
        </translate>
      </p>
    </div>
  </div>
</template>

<script>
import axios from 'axios'

export default {
  props: {
    modelValue: { type: String, default: '' },
    fieldId: { type: String, default: 'change-content' },
    placeholder: { type: String, default: null },
    autofocus: { type: Boolean, default: false },
    charLimit: { type: Number, default: 5000, required: false },
    rows: { type: Number, default: 5, required: false },
    permissive: { type: Boolean, default: false },
    required: { type: Boolean, default: false }
  },
  data () {
    return {
      isPreviewing: false,
      preview: null,
      newValue: this.modelValue,
      isLoadingPreview: false
    }
  },
  computed: {
    labels () {
      return {
        placeholder: this.$pgettext('*/Form/Placeholder', 'Write a few words here…')
      }
    },
    remainingChars () {
      return this.charLimit - (this.modelValue || '').length
    }
  },
  watch: {
    newValue (v) {
      this.preview = null
      this.$emit('update:modelValue', v)
    },
    modelValue: {
      async handler (v) {
        this.preview = null
        this.newValue = v
        if (this.isPreviewing) {
          await this.loadPreview()
        }
      },
      immediate: true
    },
    async isPreviewing (v) {
      if (v && !!this.modelValue && this.preview === null && !this.isLoadingPreview) {
        await this.loadPreview()
      }
      if (!v) {
        await this.$nextTick()
        this.$refs.textarea.focus()
      }
    }
  },
  mounted () {
    if (this.autofocus) {
      this.$nextTick(() => {
        this.$refs.textarea.focus()
      })
    }
  },
  methods: {
    async loadPreview () {
      this.isLoadingPreview = true
      try {
        const response = await axios.post('text-preview/', { text: this.newValue, permissive: this.permissive })
        this.preview = response.data.rendered
      } catch (error) {
        console.error(error)
      }
      this.isLoadingPreview = false
    }
  }
}
</script>
