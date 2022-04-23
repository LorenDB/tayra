<template>
  <modal :show.sync="show">
    <h4 class="header">
      {{ labels.header }}
    </h4>
    <div
      v-if="cover"
      class="image content"
    >
      <div class="ui medium image">
        <img :src="cover.urls.medium_square_crop">
      </div>
      <div class="description">
        <div class="ui header">
          {{ labels.description }}
        </div>
        <p>
          {{ message }}
        </p>
      </div>
    </div>
    <div
      v-else
      class="content"
    >
      <div class="ui centered header">
        {{ labels.description }}
      </div>
      <p style="text-align: center;">
        {{ message }}
      </p>
    </div>
    <div class="actions">
      <router-link
        :to="{path: '/login', query: { next: nextRoute }}"
        class="ui labeled icon button"
      >
        <i class="key icon" />
        {{ labels.login }}
      </router-link>
      <router-link
        v-if="$store.state.instance.settings.users.registration_enabled.value"
        :to="{path: '/signup'}"
        class="ui labeled icon button"
      >
        <i class="user icon" />
        {{ labels.signup }}
      </router-link>
    </div>
  </modal>
</template>

<script>
import Modal from '~/components/semantic/Modal.vue'

export default {
  components: {
    Modal
  },
  props: {
    nextRoute: { type: String, required: true },
    message: { type: String, required: true },
    cover: { type: Object, required: true }
  },
  data () {
    return {
      show: false
    }
  },
  computed: {
    labels () {
      return {
        header: this.$pgettext('Popup/Title/Noun', 'Unauthenticated'),
        login: this.$pgettext('*/*/Button.Label/Verb', 'Log in'),
        signup: this.$pgettext('*/*/Button.Label/Verb', 'Sign up'),
        description: this.$pgettext('Popup/*/Paragraph', "You don't have access!")
      }
    }
  }
}

</script>
