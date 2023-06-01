<script setup lang="ts">
import type { BackendError } from '~/types'

import { computed, ref, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'

import axios from 'axios'

interface Props {
  defaultEmail: string
}

const props = defineProps<Props>()

const { t } = useI18n()

const router = useRouter()

const labels = computed(() => ({
  placeholder: t('views.auth.PasswordReset.placeholder.email'),
  reset: t('views.auth.PasswordReset.title')
}))

const email = ref(props.defaultEmail)
const errors = ref([] as string[])
const isLoading = ref(false)
const submit = async () => {
  isLoading.value = true
  errors.value = []

  try {
    await axios.post('auth/password/reset/', { email: email.value })
    router.push({ name: 'auth.password-reset-confirm' })
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}

const emailInput = ref()
onMounted(() => emailInput.value.focus())
</script>

<template>
  <main
    v-title="labels.reset"
    class="main pusher"
  >
    <section class="ui vertical stripe segment">
      <div class="ui small text container">
        <h2>
          {{ $t('views.auth.PasswordReset.header.reset') }}
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
              {{ $t('views.auth.PasswordReset.header.failure') }}
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
            {{ $t('views.auth.PasswordReset.help.form') }}
          </p>
          <div class="field">
            <label for="account-email">{{ $t('views.auth.PasswordReset.label.email') }}</label>
            <input
              id="account-email"
              ref="emailInput"
              v-model="email"
              required
              type="email"
              name="email"
              autofocus
              :placeholder="labels.placeholder"
            >
          </div>
          <router-link :to="{path: '/login'}">
            {{ $t('views.auth.PasswordReset.link.back') }}
          </router-link>
          <button
            :class="['ui', {'loading': isLoading}, 'right', 'floated', 'success', 'button']"
            type="submit"
          >
            {{ $t('views.auth.PasswordReset.button.requestReset') }}
          </button>
        </form>
      </div>
    </section>
  </main>
</template>
