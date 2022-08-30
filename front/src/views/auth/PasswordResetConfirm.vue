<script setup lang="ts">
import type { BackendError } from '~/types'

import { useGettext } from 'vue3-gettext'
import { computed, ref } from 'vue'

import axios from 'axios'

import PasswordInput from '~/components/forms/PasswordInput.vue'

interface Props {
  defaultToken: string
  defaultUid: string
}

const props = defineProps<Props>()

const { $pgettext } = useGettext()

const labels = computed(() => ({
  changePassword: $pgettext('*/Signup/Title', 'Change your password')
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
              <translate translate-context="Content/Signup/Card.Title">
                Error while changing your password
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
          <template v-if="token && uid">
            <div class="field">
              <label for="password-field"><translate translate-context="Content/Settings/Input.Label">New password</translate></label>
              <password-input
                v-model="newPassword"
                field-id="password-field"
              />
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
              <translate translate-context="Content/Signup/Button.Label">
                Update your password
              </translate>
            </button>
          </template>
          <template v-else>
            <p>
              <translate translate-context="Content/Signup/Paragraph">
                If the e-mail address provided in the previous step is valid and linked to a user account, you should receive an e-mail with reset instructions in the next couple of minutes.
              </translate>
            </p>
          </template>
        </form>
        <div
          v-else
          class="ui positive message"
        >
          <h4 class="header">
            <translate translate-context="Content/Signup/Card.Title">
              Password updated successfully
            </translate>
          </h4>
          <p>
            <translate translate-context="Content/Signup/Card.Paragraph">
              Your password has been updated successfully.
            </translate>
          </p>
          <router-link :to="{name: 'login'}">
            <translate translate-context="Content/Signup/Link/Verb">
              Proceed to login
            </translate>
          </router-link>
        </div>
      </div>
    </section>
  </main>
</template>
