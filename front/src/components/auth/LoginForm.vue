<script setup lang="ts">
import type { BackendError } from '~/types'
import type { RouteLocationRaw } from 'vue-router'

import { ref, reactive, computed, onMounted } from 'vue'
import { useGettext } from 'vue3-gettext'
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
const { $pgettext } = useGettext()
const store = useStore()

const credentials = reactive({
  username: '',
  password: ''
})

const labels = computed(() => ({
  usernamePlaceholder: $pgettext('Content/Login/Input.Placeholder', 'Enter your username or e-mail address')
}))

const username = ref()
onMounted(() => username.value.focus())

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
        <translate translate-context="Content/Login/Error message.Title">
          We cannot log you in
        </translate>
      </h4>
      <ul class="list">
        <li v-if="errors[0] == 'invalid_credentials' && $store.state.instance.settings.moderation.signup_approval_enabled.value">
          <translate translate-context="Content/Login/Error message.List item/Call to action">
            If you signed-up recently, you may need to wait before our moderation team review your account, or verify your e-mail address.
          </translate>
        </li>
        <li v-else-if="errors[0] == 'invalid_credentials'">
          <translate translate-context="Content/Login/Error message.List item/Call to action">
            Please double-check that your username and password combination is correct and make sure you verified your e-mail address.
          </translate>
        </li>
        <li v-else>
          {{ errors[0] }}
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
