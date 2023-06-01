<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { computed, ref } from 'vue'

import axios from 'axios'

import ApplicationForm from '~/components/auth/ApplicationForm.vue'

import useErrorHandler from '~/composables/useErrorHandler'
import { useStore } from '~/store'

interface Props {
  id: number
}

const props = defineProps<Props>()

const { t } = useI18n()

const application = ref()

const labels = computed(() => ({
  title: t('components.auth.ApplicationEdit.title')
}))

const isLoading = ref(false)
const fetchApplication = async () => {
  isLoading.value = true

  try {
    const response = await axios.get(`oauth/apps/${props.id}/`)
    application.value = response.data
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoading.value = false
}

const refreshToken = async () => {
  isLoading.value = true

  try {
    const response = await axios.post(`oauth/apps/${props.id}/refresh-token`)
    application.value = response.data
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoading.value = false
}

fetchApplication()

const store = useStore()
const secret = store.state.auth.applicationSecret
store.state.auth.applicationSecret = undefined
</script>

<template>
  <main
    v-title="labels.title"
    class="main pusher"
  >
    <div class="ui vertical stripe segment">
      <section class="ui text container">
        <div
          v-if="isLoading"
          class="ui inverted active dimmer"
        >
          <div class="ui loader" />
        </div>
        <template v-else>
          <router-link :to="{name: 'settings'}">
            {{ $t('components.auth.ApplicationEdit.link.settings') }}
          </router-link>
          <h2 class="ui header">
            {{ $t('components.auth.ApplicationEdit.header.appDetails') }}
          </h2>
          <div class="ui form">
            <p>
              {{ $t('components.auth.ApplicationEdit.help.appDetails') }}
            </p>
            <div class="field">
              <label for="copy-id">{{ $t('components.auth.ApplicationEdit.label.appId') }}</label>
              <copy-input
                id="copy-id"
                :value="application.client_id"
              />
            </div>
            <div
              v-if="secret"
              class="field"
            >
              <div class="ui small warning message">
                <h3 class="header">
                  {{ $t('components.auth.ApplicationEdit.header.appSecretWarning') }}
                </h3>
                <p>
                  {{ $t('components.auth.ApplicationEdit.message.appSecretWarning') }}
                </p>
              </div>

              <label for="copy-secret">{{ $t('components.auth.ApplicationEdit.label.appSecret') }}</label>
              <copy-input
                id="copy-secret"
                :value="secret"
              />
            </div>
            <div
              v-if="application.token != undefined"
              class="field"
            >
              <label for="copy-secret">{{ $t('components.auth.ApplicationEdit.label.accessToken') }}</label>
              <copy-input
                id="copy-secret"
                :value="application.token"
              />
              <a
                href=""
                @click.prevent="refreshToken"
              >
                <i class="refresh icon" />
                {{ $t('components.auth.ApplicationEdit.button.regenerateToken') }}
              </a>
            </div>
          </div>
          <h2 class="ui header">
            {{ $t('components.auth.ApplicationEdit.header.editApp') }}
          </h2>
          <application-form
            :app="application"
            @updated="application = $event"
          />
        </template>
      </section>
    </div>
  </main>
</template>
