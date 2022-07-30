<script setup lang="ts">
import type { BackendError } from '~/types'

import { useGettext } from 'vue3-gettext'
import { computed, ref } from 'vue'
import { useStore } from '~/store'
import axios from 'axios'

import PasswordInput from '~/components/forms/PasswordInput.vue'

const { $pgettext } = useGettext()
const store = useStore()

const subsonicEnabled = computed(() => store.state.instance.settings.subsonic.enabled.value)
const labels = computed(() => ({
  subsonicField: $pgettext('Content/Password/Input.label', 'Your subsonic API password')
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
  successMessage.value = $pgettext('Content/Settings/Message', 'Password updated')
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
  successMessage.value = $pgettext('Content/Settings/Message', 'Access disabled')
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
      <translate translate-context="Content/Settings/Title">
        Subsonic API password
      </translate>
    </h2>
    <p
      v-if="!subsonicEnabled"
      class="ui message"
    >
      <translate translate-context="Content/Settings/Paragraph">
        The Subsonic API is not available on this Funkwhale instance.
      </translate>
    </p>
    <p>
      <translate translate-context="Content/Settings/Paragraph'">
        Funkwhale is compatible with other music players that support the Subsonic API.
      </translate>&nbsp;<translate translate-context="Content/Settings/Paragraph">
        You can use those to enjoy your playlist and music in offline mode, on your smartphone or tablet, for instance.
      </translate>
    </p>
    <p>
      <translate translate-context="Content/Settings/Paragraph">
        However, accessing Funkwhale from those clients requires a separate password you can set below.
      </translate>
    </p>
    <p>
      <a
        href="https://docs.funkwhale.audio/users/apps.html#subsonic-compatible-clients"
        target="_blank"
      >
        <translate translate-context="Content/Settings/Link">Discover how to use Funkwhale from other apps</translate>
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
        <translate translate-context="Content/*/Error message.Title">
          Error
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
        <translate translate-context="*/Settings/Button.Label/Verb">
          Request a new password
        </translate>
        <template #modal-header>
          <p>
            <translate translate-context="Popup/Settings/Title">
              Request a new Subsonic API password?
            </translate>
          </p>
        </template>
        <template #modal-content>
          <p>
            <translate translate-context="Popup/Settings/Paragraph">
              This will log you out from existing devices that use the current password.
            </translate>
          </p>
        </template>
        <template #modal-confirm>
          <div>
            <translate translate-context="*/Settings/Button.Label/Verb">
              Request a new password
            </translate>
          </div>
        </template>
      </dangerous-button>
      <button
        v-else
        color=""
        :class="['ui', {'loading': isLoading}, 'button']"
        @click="requestNewToken"
      >
        <translate translate-context="Content/Settings/Button.Label/Verb">
          Request a password
        </translate>
      </button>
      <dangerous-button
        v-if="token"
        :class="['ui', {'loading': isLoading}, 'warning', 'button']"
        :action="disable"
      >
        <translate translate-context="Content/Settings/Button.Label/Verb">
          Disable Subsonic access
        </translate>
        <template #modal-header>
          <p>
            <translate translate-context="Popup/Settings/Title">
              Disable Subsonic API access?
            </translate>
          </p>
        </template>
        <template #modal-content>
          <p>
            <translate translate-context="Popup/Settings/Paragraph">
              This will completely disable access to the Subsonic API using from account.
            </translate>
          </p>
        </template>
        <template #modal-confirm>
          <div>
            <translate translate-context="Popup/Settings/Button.Label">
              Disable access
            </translate>
          </div>
        </template>
      </dangerous-button>
    </template>
  </form>
</template>
