<script setup lang="ts">
import type { BackendError } from '~/types'

import { useI18n } from 'vue-i18n'
import { computed, ref } from 'vue'

import axios from 'axios'

import PasswordInput from '~/components/forms/PasswordInput.vue'

interface Props {
  defaultToken: string
  defaultUid: string
}

const props = defineProps<Props>()

const { t } = useI18n()

const labels = computed(() => ({
  changePassword: t('views.auth.PasswordResetConfirm.title')
}))

const newPassword = ref('')
const token = ref(props.defaultToken)
const uid = ref(props.defaultUid)

const errors = ref([] as string[])
const isLoading = ref(false)
const success = ref(false)
const submit = async () => {
  isLoading.value = true
  errors.value = []

  try {
    await axios.post('auth/password/reset/confirm/', {
      uid: uid.value,
      token: token.value,
      new_password1: newPassword.value,
      new_password2: newPassword.value
    })

    success.value = true
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}
</script>

<template>
  <main
    v-title="labels.changePassword"
    class="main pusher"
  >
    <section class="ui vertical stripe segment">
      <div class="ui small text container">
        <h2>{{ labels.changePassword }}</h2>
        <form
          v-if="!success"
          class="ui form"
          @submit.prevent="submit()"
        >
          <div
            v-if="errors.length > 0"
            role="alert"
            class="ui negative message"
          >
            <h4 class="header">
              {{ $t('views.auth.PasswordResetConfirm.header.failure') }}
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
          <template v-if="token && uid">
            <div class="field">
              <label for="password-field">{{ $t('views.auth.PasswordResetConfirm.label.newPassword') }}</label>
              <password-input
                v-model="newPassword"
                field-id="password-field"
              />
            </div>
            <router-link :to="{path: '/login'}">
              {{ $t('views.auth.PasswordResetConfirm.link.back') }}
            </router-link>
            <button
              :class="['ui', {'loading': isLoading}, 'right', 'floated', 'success', 'button']"
              type="submit"
            >
              {{ $t('views.auth.PasswordResetConfirm.button.update') }}
            </button>
          </template>
          <template v-else>
            <p>
              {{ $t('views.auth.PasswordResetConfirm.message.requestSent') }}
            </p>
          </template>
        </form>
        <div
          v-else
          class="ui positive message"
        >
          <h4 class="header">
            {{ $t('views.auth.PasswordResetConfirm.header.success') }}
          </h4>
          <p>
            {{ $t('views.auth.PasswordResetConfirm.message.success') }}
          </p>
          <router-link :to="{name: 'login'}">
            {{ $t('views.auth.PasswordResetConfirm.link.login') }}
          </router-link>
        </div>
      </div>
    </section>
  </main>
</template>
