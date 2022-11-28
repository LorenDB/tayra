<script setup lang="ts">
import type { BackendError } from '~/types'
import type { RouteLocationRaw } from 'vue-router'

import { ref, reactive, computed, onMounted, nextTick } from 'vue'
import { useRouter } from 'vue-router'
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
const router = useRouter()

const credentials = reactive({
  username: '',
  password: ''
})

const labels = computed(() => ({
  usernamePlaceholder: t('components.auth.LoginForm.placeholder.username')
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
      await router.push(props.next)
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
        {{ $t('components.auth.LoginForm.header.loginFailure') }}
      </h4>
      <ul class="list">
        <li v-if="errors[0] == 'invalid_credentials' && $store.state.instance.settings.moderation.signup_approval_enabled.value">
          {{ $t('components.auth.LoginForm.help.approvalRequired') }}
        </li>
        <li v-else-if="errors[0] == 'invalid_credentials'">
          {{ $t('components.auth.LoginForm.help.invalidCredentials') }}
        </li>
        <li v-else>
          {{ errors[0] }}
        </li>
      </ul>
    </div>
    <template v-if="domain === $store.getters['instance/domain']">
      <div class="field">
        <label for="username-field">
          {{ $t('components.auth.LoginForm.label.username') }}
          <template v-if="showSignup">
            <span class="middle pipe symbol" />
            <router-link :to="{path: '/signup'}">
              {{ $t('components.auth.LoginForm.link.createAccount') }}
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
          {{ $t('components.auth.LoginForm.label.password') }}
          <span class="middle pipe symbol" />
          <router-link
            tabindex="1"
            :to="{name: 'auth.password-reset', query: {email: credentials.username}}"
          >
            {{ $t('components.auth.LoginForm.link.resetPassword') }}
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
        {{ $t('components.auth.LoginForm.message.redirect', { domain: $store.getters['instance/domain'] }) }}
      </p>
    </template>
    <button
      :class="['ui', {'loading': isLoading}, 'right', 'floated', buttonClasses, 'button']"
      type="submit"
    >
      {{ $t('components.auth.LoginForm.button.login') }}
    </button>
  </form>
</template>
