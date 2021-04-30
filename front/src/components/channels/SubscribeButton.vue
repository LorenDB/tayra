 <template>
  <button v-if="$store.state.auth.authenticated" @click.stop="toggle" :class="['ui', 'pink', {'inverted': isSubscribed}, {'favorited': isSubscribed}, 'icon', 'labeled', 'button']">
    <i class="heart icon"></i>
    <translate v-if="isSubscribed" translate-context="Content/Track/Button.Message">Unsubscribe</translate>
    <translate v-else translate-context="Content/Track/*/Verb">Subscribe</translate>
  </button>
  <button @click="$refs.loginModal.show = true" v-else :class="['ui', 'pink', 'icon', 'labeled', 'button']">
    <i class="heart icon"></i>
    <translate translate-context="Content/Track/*/Verb">Subscribe</translate>
    <login-modal
      ref="loginModal"
      class="small"
      :nextRoute='this.$route.fullPath'
      :message='this.message.authMessage'
      :cover='this.channel.artist.cover'
      @created="$refs.loginModal.show = false;">
    </login-modal>
  </button>
</template>

<script>
import LoginModal from '@/components/common/LoginModal'

export default {
  props: {
    channel: {type: Object},
  },
  components: {
    LoginModal
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
    },
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
