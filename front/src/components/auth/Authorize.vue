<script setup lang="ts">
import type { BackendError, Application } from '~/types'

import axios from 'axios'
import { useGettext } from 'vue3-gettext'
import { whenever } from '@vueuse/core'
import { ref, computed } from 'vue'

import useSharedLabels from '~/composables/locale/useSharedLabels'
import useScopes from '~/composables/auth/useScopes'
import useFormData from '~/composables/useFormData'

interface Props {
  clientId: string
  redirectUri: string
  scope: 'me' | 'all'
  responseType: string
  nonce: string
  state: string
}

const props = defineProps<Props>()

const { $pgettext } = useGettext()
const sharedLabels = useSharedLabels()
const knownScopes = useScopes()

const supportedScopes = ['read', 'write']
for (const scope of knownScopes) {
  supportedScopes.push(`read:${scope.id}`)
  supportedScopes.push(`write:${scope.id}`)
}

const application = ref()

const errors = ref([] as string[])
const isLoading = ref(false)
const fetchApplication = async () => {
  isLoading.value = true

  try {
    const response = await axios.get(`oauth/apps/${props.clientId}/`)
    application.value = response.data as Application
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}

const code = ref()
const submit = async () => {
  isLoading.value = true

  try {
    const data = useFormData({
      redirect_uri: props.redirectUri,
      scope: props.scope,
      allow: 'true',
      client_id: props.clientId,
      response_type: props.responseType,
      state: props.state,
      nonce: props.nonce
    })

    const response = await axios.post('oauth/authorize/', data, {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })

    if (props.redirectUri !== 'urn:ietf:wg:oauth:2.0:oob') {
      window.location.href = response.data.redirect_uri
      return
    }

    code.value = response.data.code
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}

const labels = computed(() => ({
  title: $pgettext('Head/Authorize/Title', 'Allow application')
}))

const requestedScopes = computed(() => props.scope.split(' '))
const unknownRequestedScopes = computed(() => requestedScopes.value.filter(scope => !supportedScopes.includes(scope)))
const topicScopes = computed(() => {
  const requested = requestedScopes.value

  const write = requested.includes('write')
  const read = requested.includes('read')

  return knownScopes.map(scope => {
    const { id } = scope
    return {
      id,
      icon: scope.icon,
      label: sharedLabels.scopes[id].label,
      description: sharedLabels.scopes[id].description,
      read: read || requested.includes(`read:${id}`),
      write: write || requested.includes(`write:${id}`)
    }
  }).filter(scope => scope.read || scope.write)
})

whenever(() => props.clientId, fetchApplication)
</script>

<template>
  <main
    v-title="labels.title"
    class="main pusher"
  >
    <section class="ui vertical stripe segment">
      <div class="ui small text container">
        <h2>
          <i class="lock open icon" /><translate translate-context="Content/Auth/Title/Verb">
            Authorize third-party app
          </translate>
        </h2>
        <div
          v-if="errors.length > 0"
          role="alert"
          class="ui negative message"
        >
          <h4
            v-if="application"
            class="header"
          >
            <translate translate-context="Popup/Moderation/Error message">
              Error while authorizing application
            </translate>
          </h4>
          <h4
            v-else
            class="header"
          >
            <translate translate-context="Popup/Moderation/Error message">
              Error while fetching application data
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
        <div
          v-if="isLoading"
          class="ui inverted active dimmer"
        >
          <div class="ui loader" />
        </div>
        <form
          v-else-if="application && !code"
          :class="['ui', {loading: isLoading}, 'form']"
          @submit.prevent="submit"
        >
          <h3>
            <translate
              translate-context="Content/Auth/Title"
              :translate-params="{app: application.name}"
            >
              %{ app } wants to access your Funkwhale account
            </translate>
          </h3>

          <h4
            v-for="(topic, key) in topicScopes"
            :key="key"
            class="ui header vertical-align"
          >
            <span
              v-if="topic.write && !topic.read"
              :class="['ui', 'basic', 'right floated', 'tiny', 'vertically-spaced component-label label']"
            >
              <i class="pencil icon" />
              <translate translate-context="Content/Auth/Label/Noun">Write-only</translate>
            </span>
            <span
              v-else-if="!topic.write && topic.read"
              :class="['ui', 'basic', 'right floated', 'tiny', 'vertically-spaced component-label label']"
            >
              <translate translate-context="Content/Auth/Label/Noun">Read-only</translate>
            </span>
            <span
              v-else-if="topic.write && topic.read"
              :class="['ui', 'basic', 'right floated', 'tiny', 'vertically-spaced component-label label']"
            >
              <i class="pencil icon" />
              <translate translate-context="Content/Auth/Label/Noun">Full access</translate>
            </span>
            <i :class="[topic.icon, 'icon']" />
            <div class="content">
              {{ topic.label }}
              <div class="sub header">
                {{ topic.description }}
              </div>
            </div>
          </h4>
          <div v-if="unknownRequestedScopes.length > 0">
            <p><strong><translate translate-context="Content/Auth/Paragraph">The application is also requesting the following unknown permissions:</translate></strong></p>
            <ul
              v-for="(unknownscope, key) in unknownRequestedScopes"
              :key="key"
            >
              <li>{{ unknownscope }}</li>
            </ul>
          </div>
          <button
            class="ui success labeled icon button"
            type="submit"
          >
            <i class="lock open icon" />
            <translate
              translate-context="Content/Signup/Button.Label/Verb"
              :translate-params="{app: application.name}"
            >
              Authorize %{ app }
            </translate>
          </button>
          <p
            v-if="redirectUri === 'urn:ietf:wg:oauth:2.0:oob'"
            v-translate
            translate-context="Content/Auth/Paragraph"
          >
            You will be shown a code to copy-paste in the application.
          </p>
          <p
            v-else
            v-translate="{url: redirectUri}"
            translate-context="Content/Auth/Paragraph"
            :translate-params="{url: redirectUri}"
          >
            You will be redirected to <strong>%{ url }</strong>
          </p>
        </form>
        <div v-else-if="code">
          <p><strong><translate translate-context="Content/Auth/Paragraph">Copy-paste the following code in the application:</translate></strong></p>
          <copy-input :value="code" />
        </div>
      </div>
    </section>
  </main>
</template>
