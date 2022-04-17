<template>
  <button
    :class="['ui', 'primary', {'inverted': running}, 'icon', 'labeled', 'button']"
    @click="toggleRadio"
  >
    <i
      class="ui feed icon"
      role="button"
    />
    {{ buttonLabel }}
  </button>
</template>

<script>

import { isEqual } from 'lodash-es'
export default {
  props: {
    customRadioId: { type: Number, required: false, default: null },
    type: { type: String, required: false, default: '' },
    clientOnly: { type: Boolean, default: false },
    objectId: { type: [String, Number, Object], default: null },
    config: { type: [Array, Object], required: false, default: null }
  },
  computed: {
    running () {
      const state = this.$store.state.radios
      const current = state.current
      if (!state.running) {
        return false
      } else {
        return current.type === this.type && isEqual(current.objectId, this.objectId) && current.customRadioId === this.customRadioId
      }
    },
    label () {
      return this.config?.[0]?.type ?? null
    },
    buttonLabel () {
      switch (this.label) {
        case 'tag':
          return this.running
            ? this.$pgettext('*/Player/Button.Label/Short, Verb', 'Stop tags radio')
            : this.$pgettext('*/Player/Button.Label/Short, Verb', 'Start tags radio')
        case 'artist':
          return this.running
            ? this.$pgettext('*/Player/Button.Label/Short, Verb', 'Stop artists radio')
            : this.$pgettext('*/Player/Button.Label/Short, Verb', 'Start artists radio')
        default:
          return this.running
            ? this.$pgettext('*/Player/Button.Label/Short, Verb', 'Stop radio')
            : this.$pgettext('*/Queue/Button.Label/Short, Verb', 'Play radio')
      }
    }
  },
  methods: {
    toggleRadio () {
      if (this.running) {
        this.$store.dispatch('radios/stop')
      } else {
        this.$store.dispatch('radios/start', {
          type: this.type,
          objectId: this.objectId,
          customRadioId: this.customRadioId,
          clientOnly: this.clientOnly,
          config: this.config
        })
      }
    }
  }
}
</script>
