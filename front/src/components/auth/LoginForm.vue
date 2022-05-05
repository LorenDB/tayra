<template>
  <form
    class="ui form"
    @submit.prevent="submit()"
  >
    <div
      v-if="error"
      role="alert"
      class="ui negative message"
    >
      <h4 class="header">
        <translate translate-context="Content/Login/Error message.Title">
          We cannot log you in
        </translate>
      </h4>
      <ul class="list">
        <li v-if="error == 'invalid_credentials' && $store.state.instance.settings.moderation.signup_approval_enabled.value">
          <translate translate-context="Content/Login/Error message.List item/Call to action">
            If you signed-up recently, you may need to wait before our moderation team review your account, or verify your e-mail address.
          </translate>
        </li>
        <li v-else-if="error == 'invalid_credentials'">
          <translate translate-context="Content/Login/Error message.List item/Call to action">
            Please double-check that your username and password combination is correct and make sure you verified your e-mail address.
          </translate>
        </li>
        <li v-else>
          {{ error }}
        </li>
      </ul>
    </div>
    <template v-if="domain === $store.getters['instance/domain']">
      <div class="field">
        <label for="username-field">
          <translate translate-context="Content/Login/Input.Label/Noun">Username or e-mail address</translate>
          <template v-if="showSignup">
            |
            <router-link :to="{path: '/signup'}">
              <translate translate-context="*/Signup/Link/Verb">Create an account</translate>
            </router-link>
          </template>
        </label>
        <input
          id="username-field"
          ref="username"
          v-model="credentials.username"
          required
          name="username"
          type="text"
          autofocus
          :placeholder="labels.usernamePlaceholder"
        >
      </div>
      <div class="field">
        <label for="password-field">
          <translate translate-context="*/*/*">Password</translate> |
          <router-link
            tabindex="1"
            :to="{name: 'auth.password-reset', query: {email: credentials.username}}"
          >
            <translate translate-context="*/Login/*/Verb">Reset your password</translate>
          </router-link>
        </label>
        <password-input
          v-model="credentials.password"
          field-id="password-field"
          required
        />
      </div>
    </template>
    <template v-else>
      <p>
        <translate
          translate-context="Contant/Auth/Paragraph"
          :translate-params="{domain: $store.getters['instance/domain']}"
        >
          You will be redirected to %{ domain } to authenticate.
        </translate>
      </p>
    </template>
    <button
      :class="['ui', {'loading': isLoading}, 'right', 'floated', buttonClasses, 'button']"
      type="submit"
    >
      <translate translate-context="*/Login/*/Verb">
        Login
      </translate>
    </button>
  </form>
</template>

<script>
import PasswordInput from '~/components/forms/PasswordInput.vue'

export default {
  components: {
    PasswordInput
  },
  props: {
    next: { type: String, default: '/library' },
    buttonClasses: { type: String, default: 'success' },
    showSignup: { type: Boolean, default: true }
  },
  data () {
    return {
      // We need to initialize the component with any
      // properties that will be used in it
      credentials: {
        username: '',
        password: ''
      },
      error: '',
      isLoading: false,
      domain: location.hostname
    }
  },
  computed: {
    labels () {
      const usernamePlaceholder = this.$pgettext('Content/Login/Input.Placeholder', 'Enter your username or e-mail address')
      return {
        usernamePlaceholder
      }
    }
  },
  created () {
    if (this.$store.state.auth.authenticated) {
      this.$router.push(this.next)
    }
  },
  mounted () {
    if (this.$refs.username) {
      this.$refs.username.focus()
    }
  },
  methods: {
    async submit () {
      if (location.hostname === this.$store.getters['instance/domain']) {
        return await this.submitSession()
      } else {
        this.isLoading = true
        await this.$store.dispatch('auth/oauthLogin', this.next)
      }
    },
    async submitSession () {
      this.isLoading = true
      this.error = ''
      const credentials = {
        username: this.credentials.username,
        password: this.credentials.password
      }
      this.$store
        .dispatch('auth/login', {
          credentials,
          next: this.next,
          onError: error => {
            if (error.response.status === 400) {
              self.error = 'invalid_credentials'
            } else {
              self.error = error.backendErrors[0]
            }
          }
        })
        .then(() => {
          self.isLoading = false
        })
    }
  }
}
</script>
