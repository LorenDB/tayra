<script setup lang="ts">
import type { RouteLocationRaw } from 'vue-router'
import type { BackendError, Form } from '~/types'

import { computed, reactive, ref } from 'vue'
import { useGettext } from 'vue3-gettext'
import { useStore } from '~/store'

import axios from 'axios'

import LoginForm from '~/components/auth/LoginForm.vue'
import PasswordInput from '~/components/forms/PasswordInput.vue'
import useLogger from '~/composables/useLogger'

interface Props {
  defaultInvitation?: string | null
  next?: RouteLocationRaw
  buttonClasses?: string
  customization?: Form | null
  fetchDescriptionHtml?: boolean
  signupApprovalEnabled?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  defaultInvitation: null,
  next: '/',
  buttonClasses: 'success',
  customization: null,
  fetchDescriptionHtml: false,
  signupApprovalEnabled: false
})

const { $pgettext } = useGettext()
const logger = useLogger()
const store = useStore()

const labels = computed(() => ({
  placeholder: $pgettext('Content/Signup/Form/Placeholder', 'Enter your invitation code (case insensitive)'),
  usernamePlaceholder: $pgettext('Content/Signup/Form/Placeholder', 'Enter your username'),
  emailPlaceholder: $pgettext('Content/Signup/Form/Placeholder', 'Enter your e-mail address')
}))

const signupRequiresApproval = computed(() => props.signupApprovalEnabled ?? store.state.instance.settings.moderation.signup_approval_enabled.value)
const formCustomization = computed(() => props.customization ?? store.state.instance.settings.moderation.signup_form_customization.value)

const payload = reactive({
  username: '',
  password1: '',
  email: '',
  invitation: props.defaultInvitation,
  request_fields: {}
})

const submitted = ref(false)
const isLoading = ref(false)
const errors = ref([] as string[])
const submit = async () => {
  isLoading.value = true
  errors.value = []

  try {
    await axios.post('auth/registration/', {
      ...payload,
      password2: payload.password1
    })

    logger.info('Successfully created account')
    submitted.value = true
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}

const isLoadingInstanceSetting = ref(false)
const fetchInstanceSettings = async () => {
  isLoadingInstanceSetting.value = true
  await store.dispatch('instance/fetchSettings')
  isLoadingInstanceSetting.value = false
}

fetchInstanceSettings()
</script>

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
        v-model="payload.username"
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
        v-model="payload.email"
        name="email"
        required
        type="email"
        :placeholder="labels.emailPlaceholder"
      >
    </div>
    <div class="required field">
      <label for="password-field"><translate translate-context="*/*/*">Password</translate></label>
      <password-input
        v-model="payload.password1"
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
        v-model="payload.invitation"
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
          v-model="payload.request_fields[field.label]"
          :required="field.required"
          rows="5"
        />
        <input
          v-else
          :id="`custom-field-${idx}`"
          v-model="payload.request_fields[field.label]"
          type="text"
          :required="field.required"
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
