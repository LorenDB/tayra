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
  subsonicField: t('Your subsonic API password')
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
  successMessage.value = t('Password updated')
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
  successMessage.value = t('Access disabled')
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
      Subsonic API password
    </h2>
    <p
      v-if="!subsonicEnabled"
      class="ui message"
    >
      The Subsonic API is not available on this Funkwhale instance.
    </p>
    <p>
      Funkwhale is compatible with other music players that support the Subsonic API.&nbsp;        You can use those to enjoy your playlist and music in offline mode, on your smartphone or tablet, for instance.
    </p>
    <p>
      However, accessing Funkwhale from those clients requires a separate password you can set below.
    </p>
    <p>
      <a
        href="https://docs.funkwhale.audio/users/apps.html#subsonic-compatible-clients"
        target="_blank"
      >
        Discover how to use Funkwhale from other apps
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
        Error
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
        Request a new password
        <template #modal-header>
          <p>
            Request a new Subsonic API password?
          </p>
        </template>
        <template #modal-content>
          <p>
            This will log you out from existing devices that use the current password.
          </p>
        </template>
        <template #modal-confirm>
          <div>
            Request a new password
          </div>
        </template>
      </dangerous-button>
      <button
        v-else
        color=""
        :class="['ui', {'loading': isLoading}, 'button']"
        @click="requestNewToken"
      >
        Request a password
      </button>
      <dangerous-button
        v-if="token"
        :class="['ui', {'loading': isLoading}, 'warning', 'button']"
        :action="disable"
      >
        Disable Subsonic access
        <template #modal-header>
          <p>
            Disable Subsonic API access?
          </p>
        </template>
        <template #modal-content>
          <p>
            This will completely disable access to the Subsonic API using from account.
          </p>
        </template>
        <template #modal-confirm>
          <div>
            Disable access
          </div>
        </template>
      </dangerous-button>
    </template>
  </form>
</template>
