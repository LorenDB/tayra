<template>
  <div v-if="submitted">
    <div class="ui success message">
      <p v-if="signupRequiresApproval">
        <translate translate-context="Content/Signup/Form/Paragraph">
          Your account request was successfully submitted. You will be notified by e-mail when our moderation team has reviewed your request.
        </translate>
      </p>
      <p v-else>
        <translate translate-context="Content/Signup/Form/Paragraph">
          Your account was successfully created. Please verify your e-mail address before trying to login.
        </translate>
      </p>
    </div>
    <h2>
      <translate translate-context="Content/Login/Title/Verb">
        Log in to your Funkwhale account
      </translate>
    </h2>
    <login-form
      button-classes="basic success"
      :show-signup="false"
    />
  </div>
  <form
    v-else
    :class="['ui', {'loading': isLoadingInstanceSetting}, 'form']"
    @submit.prevent="submit()"
  >
    <p
      v-if="!$store.state.instance.settings.users.registration_enabled.value"
      class="ui message"
    >
      <translate translate-context="Content/Signup/Form/Paragraph">
        Public registrations are not possible on this instance. You will need an invitation code to sign up.
      </translate>
    </p>
    <p
      v-else-if="signupRequiresApproval"
      class="ui message"
    >
      <translate translate-context="Content/Signup/Form/Paragraph">
        Registrations on this pod are open, but reviewed by moderators before approval.
      </translate>
    </p>
    <template v-if="formCustomization && formCustomization.help_text">
      <rendered-description
        :content="formCustomization.help_text"
        :fetch-html="fetchDescriptionHtml"
        :permissive="true"
      />
      <div class="ui hidden divider" />
    </template>
    <div
      v-if="errors.length > 0"
      role="alert"
      class="ui negative message"
    >
      <h4 class="header">
        <translate translate-context="Content/Signup/Form/Paragraph">
          Your account cannot be created.
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
    <div class="required field">
      <label for="username-field"><translate translate-context="Content/*/*">Username</translate></label>
      <input
        id="username-field"
        ref="username"
        v-model="username"
        name="username"
        required
        type="text"
        autofocus
        :placeholder="labels.usernamePlaceholder"
      >
    </div>
    <div class="required field">
      <label for="email-field"><translate translate-context="Content/*/*/Noun">E-mail address</translate></label>
      <input
        id="email-field"
        ref="email"
        v-model="email"
        name="email"
        required
        type="email"
        :placeholder="labels.emailPlaceholder"
      >
    </div>
    <div class="required field">
      <label for="password-field"><translate translate-context="*/*/*">Password</translate></label>
      <password-input
        v-model="password"
        field-id="password-field"
      />
    </div>
    <div
      v-if="!$store.state.instance.settings.users.registration_enabled.value"
      class="required field"
    >
      <label for="invitation-code"><translate translate-context="Content/*/Input.Label">Invitation code</translate></label>
      <input
        id="invitation-code"
        v-model="invitation"
        required
        type="text"
        name="invitation"
        :placeholder="labels.placeholder"
      >
    </div>
    <template v-if="signupRequiresApproval && formCustomization && formCustomization.fields && formCustomization.fields.length > 0">
      <div
        v-for="(field, idx) in formCustomization.fields"
        :key="idx"
        :class="[{required: field.required}, 'field']"
      >
        <label :for="`custom-field-${idx}`">{{ field.label }}</label>
        <textarea
          v-if="field.input_type === 'long_text'"
          :id="`custom-field-${idx}`"
          :value="customFields[field.label]"
          :required="field.required"
          rows="5"
          @input="$set(customFields, field.label, $event.target.value)"
        />
        <input
          v-else
          :id="`custom-field-${idx}`"
          type="text"
          :value="customFields[field.label]"
          :required="field.required"
          @input="$set(customFields, field.label, $event.target.value)"
        >
      </div>
    </template>
    <button
      :class="['ui', buttonClasses, {'loading': isLoading}, ' right floated button']"
      type="submit"
    >
      <translate translate-context="Content/Signup/Button.Label">
        Create my account
      </translate>
    </button>
  </form>
</template>

<script>
import axios from 'axios'

import LoginForm from '~/components/auth/LoginForm.vue'
import PasswordInput from '~/components/forms/PasswordInput.vue'
import useLogger from '~/composables/useLogger'

const logger = useLogger()

export default {
  components: {
    LoginForm,
    PasswordInput
  },
  props: {
    defaultInvitation: { type: String, required: false, default: null },
    next: { type: String, default: '/' },
    buttonClasses: { type: String, default: 'success' },
    customization: { type: Object, default: null },
    fetchDescriptionHtml: { type: Boolean, default: false },
    signupApprovalEnabled: { type: Boolean, default: null, required: false }
  },
  data () {
    return {
      username: '',
      email: '',
      password: '',
      isLoadingInstanceSetting: true,
      errors: [],
      isLoading: false,
      invitation: this.defaultInvitation,
      customFields: {},
      submitted: false
    }
  },
  computed: {
    labels () {
      const placeholder = this.$pgettext(
        'Content/Signup/Form/Placeholder',
        'Enter your invitation code (case insensitive)'
      )
      const usernamePlaceholder = this.$pgettext('Content/Signup/Form/Placeholder', 'Enter your username')
      const emailPlaceholder = this.$pgettext('Content/Signup/Form/Placeholder', 'Enter your e-mail address')
      return {
        usernamePlaceholder,
        emailPlaceholder,
        placeholder
      }
    },
    formCustomization () {
      return this.customization || this.$store.state.instance.settings.moderation.signup_form_customization.value
    },
    signupRequiresApproval () {
      if (this.signupApprovalEnabled === null) {
        return this.$store.state.instance.settings.moderation.signup_approval_enabled.value
      }
      return this.signupApprovalEnabled
    }
  },
  created () {
    const self = this
    this.$store.dispatch('instance/fetchSettings', {
      callback: function () {
        self.isLoadingInstanceSetting = false
      }
    })
  },
  methods: {
    submit () {
      const self = this
      self.isLoading = true
      this.errors = []
      const payload = {
        username: this.username,
        password1: this.password,
        password2: this.password,
        email: this.email,
        invitation: this.invitation,
        request_fields: this.customFields
      }
      return axios.post('auth/registration/', payload).then(
        response => {
          logger.info('Successfully created account')
          self.submitted = true
          self.isLoading = false
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
