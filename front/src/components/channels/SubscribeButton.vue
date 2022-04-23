<template>
  <button
    v-if="$store.state.auth.authenticated"
    :class="['ui', 'pink', {'inverted': isSubscribed}, {'favorited': isSubscribed}, 'icon', 'labeled', 'button']"
    @click.stop="toggle"
  >
    <i class="heart icon" />
    <translate
      v-if="isSubscribed"
      translate-context="Content/Track/Button.Message"
    >
      Unsubscribe
    </translate>
    <translate
      v-else
      translate-context="Content/Track/*/Verb"
    >
      Subscribe
    </translate>
  </button>
  <button
    v-else
    :class="['ui', 'pink', 'icon', 'labeled', 'button']"
    @click="$refs.loginModal.show = true"
  >
    <i class="heart icon" />
    <translate translate-context="Content/Track/*/Verb">
      Subscribe
    </translate>
    <login-modal
      ref="loginModal"
      class="small"
      :next-route="$route.fullPath"
      :message="message.authMessage"
      :cover="channel.artist.cover"
      @created="$refs.loginModal.show = false;"
    />
  </button>
</template>

<script>
import LoginModal from '~/components/common/LoginModal.vue'

export default {
  components: {
    LoginModal
  },
  props: {
    channel: { type: Object, required: true }
  },
  computed: {
    title () {
      if (this.isSubscribed) {
        return this.$pgettext('Content/Channel/Button/Verb', 'Subscribe')
      } else {
        return this.$pgettext('Content/Channel/Button/Verb', 'Unsubscribe')
      }
    },
    isSubscribed () {
      return this.$store.getters['channels/isSubscribed'](this.channel.uuid)
    },
    message () {
      return {
        authMessage: this.$pgettext('Popup/Message/Paragraph', 'You need to be logged in to subscribe to this channel')
      }
    }
  },
  methods: {
    toggle () {
      if (this.isSubscribed) {
        this.$emit('unsubscribed')
      } else {
        this.$emit('subscribed')
      }
      this.$store.dispatch('channels/toggle', this.channel.uuid)
    }
  }

}
</script>
