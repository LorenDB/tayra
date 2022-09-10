<script setup lang="ts">
import type { BackendError } from '~/types'
import type { RouteLocationRaw } from 'vue-router'

import { ref, reactive, computed, onMounted, nextTick } from 'vue'
import { useI18n } from 'vue-i18n'
import { useStore } from '~/store'

import PasswordInput from '~/components/forms/PasswordInput.vue'

interface Props {
  next?: RouteLocationRaw
  buttonClasses?: string
  showSignup?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  next: '/library',
  buttonClasses: 'success',
  showSignup: true
})

const domain = location.hostname
const { t } = useI18n()
const store = useStore()

const credentials = reactive({
  username: '',
  password: ''
})

const labels = computed(() => ({
  usernamePlaceholder: t('Enter your username or e-mail address')
}))

const username = ref()
onMounted(async () => {
  await nextTick()
  username.value?.focus()
})

const isLoading = ref(false)
const errors = ref([] as string[])
const submit = async () => {
  isLoading.value = true

  try {
    if (domain === store.getters['instance/domain']) {
      await store.dispatch('auth/login', { credentials })
    } else {
      await store.dispatch('auth/oauthLogin', props.next)
    }
  } catch (error) {
    const backendError = error as BackendError

    if (backendError.response?.status === 400) {
      errors.value = ['invalid_credentials']
    } else {
      errors.value = backendError.backendErrors
    }
  }

  isLoading.value = false
}
</script>

<template>
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
        We cannot log you in
      </h4>
      <ul class="list">
        <li v-if="errors[0] == 'invalid_credentials' && $store.state.instance.settings.moderation.signup_approval_enabled.value">
          If you signed-up recently, you may need to wait before our moderation team review your account, or verify your e-mail address.
        </li>
        <li v-else-if="errors[0] == 'invalid_credentials'">
          Please double-check that your username and password combination is correct and make sure you verified your e-mail address.
        </li>
        <li v-else>
          {{ errors[0] }}
        </li>
      </ul>
    </div>
    <template v-if="domain === $store.getters['instance/domain']">
      <div class="field">
        <label for="username-field">
          Username or e-mail address
          <template v-if="showSignup">
            |
            <router-link :to="{path: '/signup'}">
              Create an account
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
          Password |
          <router-link
            tabindex="1"
            :to="{name: 'auth.password-reset', query: {email: credentials.username}}"
          >
            Reset your password
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
      Login
    </button>
  </form>
</template>
