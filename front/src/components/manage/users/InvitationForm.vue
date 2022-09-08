<script setup lang="ts">
import type { BackendError } from '~/types'

import { computed, ref, reactive } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import { useStore } from '~/store'

import axios from 'axios'

interface Invitation {
  code: string
}

const { t } = useI18n()
const router = useRouter()
const store = useStore()

const labels = computed(() => ({
  placeholder: t('Leave empty for a random code')
}))

const invitations = reactive([] as Invitation[])
const code = ref('')
const isLoading = ref(false)
const errors = ref([] as string[])
const submit = async () => {
  isLoading.value = true
  errors.value = []

  try {
    const response = await axios.post('manage/users/invitations/', { code: code.value })
    invitations.unshift(response.data)
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}

const getUrl = (code: string) => store.getters['instance/absoluteUrl'](router.resolve({
  name: 'signup',
  query: { invitation: code.toUpperCase() }
}).href)
</script>

<template>
  <div>
    <form
      class="ui form"
      @submit.prevent="submit"
    >
      <div
        v-if="errors.length > 0"
        role="alert"
        class="ui negative message"
      >
        <h4 class="header">
          <translate >
            Error while creating invitation
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
      <div class="inline fields">
        <div class="ui field">
          <label for="invitation-code"><translate >Invitation code</translate></label>
          <input
            v-model="code"
            for="invitation-code"
            name="code"
            type="text"
            :placeholder="labels.placeholder"
          >
        </div>
        <div class="ui field">
          <button
            :class="['ui', {loading: isLoading}, 'button']"
            :disabled="isLoading"
            type="submit"
          >
            <translate >
              Get a new invitation
            </translate>
          </button>
        </div>
      </div>
    </form>
    <div v-if="invitations.length > 0">
      <div class="ui hidden divider" />
      <table class="ui ui basic table">
        <thead>
          <tr>
            <th>
              <translate >
                Code
              </translate>
            </th>
            <th>
              <translate >
                Share link
              </translate>
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="invitation in invitations"
            :key="invitation.code"
          >
            <td>{{ invitation.code.toUpperCase() }}</td>
            <td>
              <a
                :href="getUrl(invitation.code)"
                target="_blank"
              >{{ getUrl(invitation.code) }}</a>
            </td>
          </tr>
        </tbody>
      </table>
      <button
        class="ui basic button"
        @click="invitations = []"
      >
        <translate >
          Clear
        </translate>
      </button>
    </div>
  </div>
</template>
