<script setup lang="ts">
import axios from 'axios'
import { useGettext } from 'vue3-gettext'
import { computed, ref } from 'vue'

import ApplicationForm from '~/components/auth/ApplicationForm.vue'

interface Props {
  id: number
}

const props = defineProps<Props>()

const { $pgettext } = useGettext()

const application = ref()

const labels = computed(() => ({
  title: $pgettext('Content/Applications/Title', 'Edit application')
}))

const isLoading = ref(false)
const fetchApplication = async () => {
  isLoading.value = true

  try {
    const response = await axios.get(`oauth/apps/${props.id}/`)
    application.value = response.data
  } catch (error) {
    // TODO (wvffle): Handle error
  }

  isLoading.value = false
}

const refreshToken = async () => {
  isLoading.value = true

  try {
    const response = await axios.post(`oauth/apps/${props.id}/refresh-token`)
    application.value = response.data
  } catch (error) {
    // TODO (wvffle): Handle error
  }

  isLoading.value = false
}

fetchApplication()
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
            <translate translate-context="Content/Applications/Link">
              Back to settings
            </translate>
          </router-link>
          <h2 class="ui header">
            <translate translate-context="Content/Applications/Title">
              Application details
            </translate>
          </h2>
          <div class="ui form">
            <p>
              <translate translate-context="Content/Application/Paragraph/">
                Application ID and secret are really sensitive values and must be treated like passwords. Do not share those with anyone else.
              </translate>
            </p>
            <div class="field">
              <label for="copy-id"><translate translate-context="Content/Applications/Label">Application ID</translate></label>
              <copy-input
                id="copy-id"
                :value="application.client_id"
              />
            </div>
            <div class="field">
              <label for="copy-secret"><translate translate-context="Content/Applications/Label">Application secret</translate></label>
              <copy-input
                id="copy-secret"
                :value="application.client_secret"
              />
            </div>
            <div
              v-if="application.token != undefined"
              class="field"
            >
              <label for="copy-secret"><translate translate-context="Content/Applications/Label">Access token</translate></label>
              <copy-input
                id="copy-secret"
                :value="application.token"
              />
              <a
                href=""
                @click.prevent="refreshToken"
              >
                <i class="refresh icon" />
                <translate translate-context="Content/Applications/Label">Regenerate token</translate>
              </a>
            </div>
          </div>
          <h2 class="ui header">
            <translate translate-context="Content/Applications/Title">
              Edit application
            </translate>
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
