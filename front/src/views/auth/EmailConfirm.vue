<script setup lang="ts">
import type { BackendError } from '~/types'

import { computed, ref, onMounted } from 'vue'
import { useGettext } from 'vue3-gettext'

import axios from 'axios'

interface Props {
  defaultKey: string
}

const props = defineProps<Props>()

const { $pgettext } = useGettext()

const labels = computed(() => ({
  confirm: $pgettext('Head/Signup/Title', 'Confirm your e-mail address')
}))

const errors = ref([] as string[])
const key = ref(props.defaultKey)
const isLoading = ref(false)
const success = ref(false)
const submit = async () => {
  isLoading.value = true
  errors.value = []

  try {
    await axios.post('auth/registration/verify-email/', { key: key.value })
    success.value = true
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}

onMounted(() => {
  if (key.value) submit()
})
</script>

<template>
  <main
    v-title="labels.confirm"
    class="main pusher"
  >
    <section class="ui vertical stripe segment">
      <div class="ui small text container">
        <h2>{{ labels.confirm }}</h2>
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
              <translate translate-context="Content/Signup/Paragraph">
                Could not confirm your e-mail address
              </translate>
            </h4>
            <ul class="list">
              <li
                v-for="(error, i) in errors"
                :key="i"
              >
                {{ error }}
              </li>
            </ul>
          </div>
          <div class="field">
            <label for="confirmation-code"><translate translate-context="Content/Signup/Form.Label">Confirmation code</translate></label>
            <input
              id="confirmation-code"
              v-model="key"
              name="confirmation-code"
              type="text"
              required
            >
          </div>
          <router-link :to="{path: '/login'}">
            <translate translate-context="Content/Signup/Link/Verb">
              Return to login
            </translate>
          </router-link>
          <button
            :class="['ui', {'loading': isLoading}, 'right', 'floated', 'success', 'button']"
            type="submit"
          >
            {{ labels.confirm }}
          </button>
        </form>
        <div
          v-else
          class="ui positive message"
        >
          <h4 class="header">
            <translate translate-context="Content/Signup/Message">
              E-mail address confirmed
            </translate>
          </h4>
          <p>
            <translate translate-context="Content/Signup/Paragraph">
              You can now use the service without limitations.
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
