<script setup lang="ts">
import type { BackendError } from '~/types'

import { useI18n } from 'vue-i18n'
import { computed, ref } from 'vue'
import { useStore } from '~/store'
import axios from 'axios'

import PasswordInput from '~/components/forms/PasswordInput.vue'

const { t } = useI18n()
const store = useStore()

const subsonicEnabled = computed(() => store.state.instance.settings.subsonic.enabled.value)
const labels = computed(() => ({
  subsonicField: t('components.auth.SubsonicTokenForm.label.subsonicField')
}))

const errors = ref([] as string[])
const success = ref(false)
const isLoading = ref(false)
const token = ref()
const fetchToken = async () => {
  success.value = false
  errors.value = []
  isLoading.value = true

  try {
    const response = await axios.get(`users/${store.state.auth.username}/subsonic-token/`)
    token.value = response.data.subsonic_api_token
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}

const showToken = ref(false)
const successMessage = ref('')
const requestNewToken = async () => {
  successMessage.value = t('components.auth.SubsonicTokenForm.message.passwordUpdated')
  success.value = false
  errors.value = []
  isLoading.value = true

  try {
    const response = await axios.post(`users/${store.state.auth.username}/subsonic-token/`)
    showToken.value = true
    token.value = response.data.subsonic_api_token
    success.value = true
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}

const disable = async () => {
  successMessage.value = t('components.auth.SubsonicTokenForm.message.accessDisabled')
  success.value = false
  errors.value = []
  isLoading.value = true

  try {
    await axios.delete(`users/${store.state.auth.username}/subsonic-token/`)
    token.value = null
    success.value = true
    showToken.value = false
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}

fetchToken()
</script>

<template>
  <form
    class="ui form"
    @submit.prevent="requestNewToken()"
  >
    <h2>
      {{ $t('components.auth.SubsonicTokenForm.header.subsonic') }}
    </h2>
    <p
      v-if="!subsonicEnabled"
      class="ui message"
    >
      {{ $t('components.auth.SubsonicTokenForm.message.unavailable') }}
    </p>
    <p>
      {{ $t('components.auth.SubsonicTokenForm.description.subsonic.paragraph1') }}&nbsp;{{ $t('components.auth.SubsonicTokenForm.description.subsonic.paragraph2') }}
    </p>
    <p>
      {{ $t('components.auth.SubsonicTokenForm.description.subsonic.paragraph3') }}
    </p>
    <p>
      <a
        href="https://docs.funkwhale.audio/users/apps.html#subsonic-compatible-clients"
        target="_blank"
      >
        {{ $t('components.auth.SubsonicTokenForm.link.apps') }}
      </a>
    </p>
    <div
      v-if="success"
      class="ui positive message"
    >
      <h4 class="header">
        {{ successMessage }}
      </h4>
    </div>
    <div
      v-if="subsonicEnabled && errors.length > 0"
      role="alert"
      class="ui negative message"
    >
      <h4 class="header">
        {{ $t('components.auth.SubsonicTokenForm.header.error') }}
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
    <template v-if="subsonicEnabled">
      <div
        v-if="token"
        class="field"
      >
        <label
          for="subsonic-password"
          class="visually-hidden"
        >{{ labels.subsonicField }}</label>
        <password-input
          ref="passwordInput"
          :key="token"
          v-model="token"
          field-id="subsonic-password"
          :copy-button="true"
          :default-show="showToken"
        />
      </div>
      <dangerous-button
        v-if="token"
        :class="['ui', {'loading': isLoading}, 'button']"
        :action="requestNewToken"
      >
        {{ $t('components.auth.SubsonicTokenForm.button.newPassword') }}
        <template #modal-header>
          <p>
            {{ $t('components.auth.SubsonicTokenForm.modal.newPassword.header') }}
          </p>
        </template>
        <template #modal-content>
          <p>
            {{ $t('components.auth.SubsonicTokenForm.modal.newPassword.content.warning') }}
          </p>
        </template>
        <template #modal-confirm>
          <div>
            {{ $t('components.auth.SubsonicTokenForm.button.confirmNewPassword') }}
          </div>
        </template>
      </dangerous-button>
      <button
        v-else
        color=""
        :class="['ui', {'loading': isLoading}, 'button']"
        @click="requestNewToken"
      >
        {{ $t('components.auth.SubsonicTokenForm.button.confirmNewPassword') }}
      </button>
      <dangerous-button
        v-if="token"
        :class="['ui', {'loading': isLoading}, 'warning', 'button']"
        :action="disable"
      >
        {{ $t('components.auth.SubsonicTokenForm.button.disable') }}
        <template #modal-header>
          <p>
            {{ $t('components.auth.SubsonicTokenForm.modal.disableSubsonic.header') }}
          </p>
        </template>
        <template #modal-content>
          <p>
            {{ $t('components.auth.SubsonicTokenForm.modal.disableSubsonic.content.warning') }}
          </p>
        </template>
        <template #modal-confirm>
          <div>
            {{ $t('components.auth.SubsonicTokenForm.button.confirmDisable') }}
          </div>
        </template>
      </dangerous-button>
    </template>
  </form>
</template>
