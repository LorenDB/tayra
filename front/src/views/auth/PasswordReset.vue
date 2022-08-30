<script setup lang="ts">
import type { BackendError } from '~/types'

import { computed, ref, onMounted } from 'vue'
import { useGettext } from 'vue3-gettext'
import { useRouter } from 'vue-router'

import axios from 'axios'

interface Props {
  defaultEmail: string
}

const props = defineProps<Props>()

const { $pgettext } = useGettext()

const router = useRouter()

const labels = computed(() => ({
  placeholder: $pgettext('Content/Signup/Input.Placeholder', 'Enter the e-mail address linked to your account'),
  reset: $pgettext('*/Login/*/Verb', 'Reset your password')
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
          <translate translate-context="*/Login/*/Verb">
            Reset your password
          </translate>
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
              <translate translate-context="Content/Signup/Card.Title">
                Error while asking for a password reset
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
          <p>
            <translate translate-context="Content/Signup/Paragraph">
              Use this form to request a password reset. We will send an e-mail to the given address with instructions to reset your password.
            </translate>
          </p>
          <div class="field">
            <label for="account-email"><translate translate-context="Content/Signup/Input.Label">Account's e-mail address</translate></label>
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
            <translate translate-context="Content/Signup/Link">
              Back to login
            </translate>
          </router-link>
          <button
            :class="['ui', {'loading': isLoading}, 'right', 'floated', 'success', 'button']"
            type="submit"
          >
            <translate translate-context="Content/Signup/Button.Label/Verb">
              Ask for a password reset
            </translate>
          </button>
        </form>
      </div>
    </section>
  </main>
</template>
