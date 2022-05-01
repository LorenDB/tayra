<template>
  <div>
    <label v-if="label"><translate translate-context="*/*/*">Category</translate></label>
    <select
      class="ui dropdown"
      :value="value"
      :required="required || null"
      @change="$emit('input', $event.target.value)"
    >
      <option
        v-if="empty"
        disabled
        value=""
      />
      <option
        v-for="(option, key) in allCategories"
        :key="key"
        :value="option.value"
      >
        {{ option.label }}
      </option>
    </select>
    <slot />
  </div>
</template>

<script>
import TranslationsMixin from '~/components/mixins/Translations.vue'
export default {
  mixins: [TranslationsMixin],
  props: {
    value: { type: String, default: null },
    all: { type: Boolean, default: null },
    label: { type: Boolean },
    empty: { type: Boolean },
    required: { type: Boolean },
    restrictTo: { type: Array, default: () => { return [] } }
  },
  computed: {
    allCategories () {
      const c = []
      if (this.all) {
        c.push(
          {
            value: '',
            label: this.$pgettext('Content/*/Dropdown', 'All')
          }
        )
      }
      let choices
      if (this.restrictTo.length > 0) {
        choices = this.restrictTo
      } else {
        choices = Object.keys(this.sharedLabels.fields.report_type.choices)
      }
      return c.concat(
        choices.sort().map((v) => {
          return {
            value: v,
            label: this.sharedLabels.fields.report_type.choices[v] || v
          }
        })
      )
    }
  }
}
</script>
