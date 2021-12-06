<template>
  <button
    :class="['ui', 'primary', {'inverted': running}, 'icon', 'labeled', 'button']"
    @click="toggleRadio"
  >
    <i
      class="ui feed icon"
      role="button"
    />
    <template v-if="running">
      <translate translate-context="*/Player/Button.Label/Short, Verb">
        Stop radio
      </translate>
    </template>
    <template v-else>
      <translate translate-context="*/Queue/Button.Label/Short, Verb">
        Play radio
      </translate>
    </template>
  </button>
</template>

<script>

import lodash from '@/lodash'
export default {
  props: {
    customRadioId: { type: Number, default: 0, required: false },
    type: { type: String, required: false, default: '' },
    clientOnly: { type: Boolean, default: false },
    objectId: { type: String, default: null }
  },
  computed: {
    running () {
      const state = this.$store.state.radios
      const current = state.current
      if (!state.running) {
        return false
      } else {
        return current.type === this.type && lodash.isEqual(current.objectId, this.objectId) && current.customRadioId === this.customRadioId
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
          clientOnly: this.clientOnly
        })
      }
    }
  }
}
</script>
