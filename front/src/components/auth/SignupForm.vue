<script setup lang="ts">
import type { RouteLocationRaw } from 'vue-router'
import type { BackendError, Form } from '~/types'

import { computed, reactive, ref, watchEffect } from 'vue'
import { useI18n } from 'vue-i18n'
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
  signupApprovalEnabled: undefined
})

const { t } = useI18n()
const logger = useLogger()
const store = useStore()

const labels = computed(() => ({
  placeholder: t('components.auth.SignupForm.placeholder.invitation'),
  usernamePlaceholder: t('components.auth.SignupForm.placeholder.username'),
  emailPlaceholder: t('components.auth.SignupForm.placeholder.email')
}))

const signupRequiresApproval = computed(() => props.signupApprovalEnabled ?? store.state.instance.settings.moderation.signup_approval_enabled.value)
const formCustomization = computed(() => props.customization ?? store.state.instance.settings.moderation.signup_form_customization.value)
watchEffect(() => logger.debug(store.state.instance.settings.moderation.signup_approval_enabled.value))

const payload = reactive({
  username: '',
  password1: '',
  email: '',
  invitation: props.defaultInvitation,
  request_fields: {} as Record<string, string | number | string[]>
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
        {{ $t('components.auth.SignupForm.message.awaitingReview') }}
      </p>
      <p v-else>
        {{ $t('components.auth.SignupForm.message.accountCreated') }}
      </p>
    </div>
    <h2>
      {{ $t('components.auth.SignupForm.header.login') }}
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
      {{ $t('components.auth.SignupForm.message.registrationClosed') }}
    </p>
    <p
      v-else-if="signupRequiresApproval"
      class="ui message"
    >
      {{ $t('components.auth.SignupForm.message.requiresReview') }}
    </p>
    <template v-if="formCustomization?.help_text">
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
        {{ $t('components.auth.SignupForm.header.signupFailure') }}
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
      <label for="username-field">{{ $t('components.auth.SignupForm.label.username') }}</label>
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
      <label for="email-field">{{ $t('components.auth.SignupForm.label.email') }}</label>
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
      <label for="password-field">{{ $t('components.auth.SignupForm.label.password') }}</label>
      <password-input
        v-model="payload.password1"
        field-id="password-field"
      />
    </div>
    <div
      v-if="!$store.state.instance.settings.users.registration_enabled.value"
      class="required field"
    >
      <label for="invitation-code">{{ $t('components.auth.SignupForm.label.invitation') }}</label>
      <input
        id="invitation-code"
        v-model="payload.invitation"
        required
        type="text"
        name="invitation"
        :placeholder="labels.placeholder"
      >
    </div>
    <template v-if="signupRequiresApproval && (formCustomization?.fields.length ?? 0) > 0">
      <div
        v-for="(field, idx) in formCustomization?.fields"
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
      {{ $t('components.auth.SignupForm.button.create') }}
    </button>
  </form>
</template>
