<template>
  <main
    v-title="labels.reset"
    class="main pusher"
  >
    <section class="ui vertical stripe segment">
      <div class="ui small text container">
        <h2>
          <translate translate-context="*/Login/*/Verb">
            Reset your password
          </translate>
        </h2>
        <form
          class="ui form"
          @submit.prevent="submit()"
        >
          <div
            v-if="errors.length > 0"
            role="alert"
            class="ui negative message"
          >
            <h4 class="header">
              <translate translate-context="Content/Signup/Card.Title">
                Error while asking for a password reset
              </translate>
            </h4>
            <ul class="list">
              <li
                v-for="(error, key) in errors"
                :key="key"
              >
                {{ error }}
              </li>
            </ul>
          </div>
          <p>
            <translate translate-context="Content/Signup/Paragraph">
              Use this form to request a password reset. We will send an e-mail to the given address with instructions to reset your password.
            </translate>
          </p>
          <div class="field">
            <label for="account-email"><translate translate-context="Content/Signup/Input.Label">Account's e-mail address</translate></label>
            <input
              id="account-email"
              ref="email"
              v-model="email"
              required
              type="email"
              name="email"
              autofocus
              :placeholder="labels.placeholder"
            >
          </div>
          <router-link :to="{path: '/login'}">
            <translate translate-context="Content/Signup/Link">
              Back to login
            </translate>
          </router-link>
          <button
            :class="['ui', {'loading': isLoading}, 'right', 'floated', 'success', 'button']"
            type="submit"
          >
            <translate translate-context="Content/Signup/Button.Label/Verb">
              Ask for a password reset
            </translate>
          </button>
        </form>
      </div>
    </section>
  </main>
</template>

<script>
import axios from 'axios'

export default {
  props: { defaultEmail: { type: String, required: true } },
  data () {
    return {
      email: this.defaultEmail,
      isLoading: false,
      errors: []
    }
  },
  computed: {
    labels () {
      const reset = this.$pgettext('*/Login/*/Verb', 'Reset your password')
      const placeholder = this.$pgettext('Content/Signup/Input.Placeholder', 'Enter the e-mail address linked to your account'
      )
      return {
        reset,
        placeholder
      }
    }
  },
  mounted () {
    this.$refs.email.focus()
  },
  methods: {
    submit () {
      const self = this
      self.isLoading = true
      self.errors = []
      const payload = {
        email: this.email
      }
      return axios.post('auth/password/reset/', payload).then(
        response => {
          self.isLoading = false
          self.$router.push({
            name: 'auth.password-reset-confirm'
          })
        },
        error => {
          self.errors = error.backendErrors
          self.isLoading = false
        }
      )
    }
  }
}
</script>
