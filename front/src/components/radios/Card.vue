<template>
  <div class="ui card">
    <div class="content">
      <h4 class="header">
        <router-link
          v-if="radio.id"
          class="discrete link"
          :to="{name: 'library.radios.detail', params: {id: radio.id}}"
        >
          {{ radio.name }}
        </router-link>
        <template v-else>
          {{ radio.name }}
        </template>
      </h4>
      <div class="description">
        {{ radio.description }}
      </div>
    </div>
    <div class="extra content">
      <user-link
        v-if="radio.user"
        :user="radio.user"
        class="left floated"
      />
      <div class="ui hidden divider" />
      <radio-button
        class="right floated button"
        :type="type"
        :custom-radio-id="customRadioId"
        :object-id="objectId"
      />
      <router-link
        v-if="$store.state.auth.authenticated && type === 'custom' && radio.user.id === $store.state.auth.profile.id"
        class="ui success button right floated"
        :to="{name: 'library.radios.edit', params: {id: customRadioId }}"
      >
        <translate translate-context="Content/*/Button.Label/Verb">
          Edit
        </translate>
      </router-link>
    </div>
  </div>
</template>

<script>
import RadioButton from './Button'

export default {
  components: {
    RadioButton
  },
  props: {
    type: { type: String, required: true, default: '' },
    customRadio: { type: Object, required: false, default: () => { return {} } },
    objectId: { type: String, required: false, default: '' }
  },
  computed: {
    radio () {
      if (this.customRadio) {
        return this.customRadio
      }
      return this.$store.getters['radios/types'][this.type]
    },
    customRadioId: function () {
      if (this.customRadio) {
        return this.customRadio.id
      }
      return null
    }
  }
}
</script>
