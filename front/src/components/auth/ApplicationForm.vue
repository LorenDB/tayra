<script setup lang="ts">
import type { BackendError, Application } from '~/types'

import axios from 'axios'
import { ref, reactive, computed } from 'vue'
import { computedEager } from '@vueuse/core'
import { useGettext } from 'vue3-gettext'
import { uniq } from 'lodash-es'

import useScopes from '~/composables/auth/useScopes'

interface Emits {
  (e: 'updated', application: Application): void
  (e: 'created', application: Application): void
}

interface Props {
  app?: Application | null
  defaults?: Partial<Application>
}

const emit = defineEmits<Emits>()
const props = withDefaults(defineProps<Props>(), {
  app: () => null,
  defaults: () => ({})
})

const { $pgettext } = useGettext()
const scopes = useScopes()
  .filter(scope => !['reports', 'security'].includes(scope.id))

const fields = reactive({
  name: props.app?.name ?? props.defaults.name ?? '',
  redirect_uris: props.app?.redirect_uris ?? props.defaults.redirect_uris ?? 'urn:ietf:wg:oauth:2.0:oob',
  scopes: props.app?.scopes ?? props.defaults.scopes ?? 'read'
})

const errors = ref([] as string[])
const isLoading = ref(false)
const submit = async () => {
  errors.value = []
  isLoading.value = true

  try {
    const event = props.app !== null
      ? 'updated'
      : 'created'

    const request = props.app !== null
      ? () => axios.patch(`oauth/apps/${props.app?.client_id}/`, fields)
      : () => axios.post('oauth/apps/', fields)

    const response = await request()
    emit(event, response.data as Application)
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}

const scopeArray = computed({
  get: () => fields.scopes.split(' '),
  set: (scopes: string[]) => uniq(scopes).join(' ')
})

const scopeParents = computedEager(() => [
  {
    id: 'read',
    label: $pgettext('Content/OAuth Scopes/Label/Verb', 'Read'),
    description: $pgettext('Content/OAuth Scopes/Help Text', 'Read-only access to user data'),
    value: scopeArray.value.includes('read')
  },
  {
    id: 'write',
    label: $pgettext('Content/OAuth Scopes/Label/Verb', 'Write'),
    description: $pgettext('Content/OAuth Scopes/Help Text', 'Write-only access to user data'),
    value: scopeArray.value.includes('write')
  }
])

const allScopes = computed(() => {
  return scopeParents.value.map(parent => ({
    ...parent,
    children: scopes.map(scope => {
      const id = `${parent.id}:${scope.id}`
      return { id, value: scopeArray.value.includes(id) }
    })
  }))
})
</script>

<template>
  <form
    class="ui form component-form"
    role="alert"
    @submit.prevent="submit()"
  >
    <div
      v-if="errors.length > 0"
      class="ui negative message"
    >
      <h4 class="header">
        <translate translate-context="Content/*/Error message.Title">
          We cannot save your changes
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
    <div class="ui field">
      <label for="application-name"><translate translate-context="*/*/*/Noun">Name</translate></label>
      <input
        id="application-name"
        v-model="fields.name"
        name="name"
        required
        type="text"
      >
    </div>
    <div class="ui field">
      <label for="redirect-uris"><translate translate-context="Content/Applications/Input.Label/Noun">Redirect URI</translate></label>
      <input
        id="redirect-uris"
        v-model="fields.redirect_uris"
        name="redirect_uris"
        type="text"
      >
      <p class="help">
        <translate translate-context="Content/Applications/Help Text">
          Use "urn:ietf:wg:oauth:2.0:oob" as a redirect URI if your application is not served on the web.
        </translate>
      </p>
    </div>
    <div class="ui field">
      <label><translate translate-context="Content/*/*/Noun">Scopes</translate></label>
      <p>
        <translate translate-context="Content/Applications/Paragraph/">
          Checking the parent "Read" or "Write" scopes implies access to all the corresponding children scopes.
        </translate>
      </p>
      <div class="ui stackable two column grid">
        <div
          v-for="(parent, key) in allScopes"
          :key="key"
          class="column"
        >
          <div class="ui parent checkbox">
            <input
              :id="parent.id"
              v-model="scopeArray"
              :value="parent.id"
              type="checkbox"
            >
            <label :for="parent.id">
              {{ parent.label }}
              <p class="help">
                {{ parent.description }}
              </p>
            </label>
          </div>

          <div
            v-for="child in parent.children"
            :key="child.id"
          >
            <div class="ui child checkbox">
              <input
                :id="child.id"
                v-model="scopeArray"
                :value="child.id"
                type="checkbox"
              >
              <label :for="child.id">
                {{ child.id }}
              </label>
            </div>
          </div>
        </div>
      </div>
    </div>
    <button
      :class="['ui', {'loading': isLoading}, 'success', 'button']"
      type="submit"
    >
      <translate
        v-if="app !== null"
        translate-context="Content/Applications/Button.Label/Verb"
      >
        Update application
      </translate>
      <translate
        v-else
        translate-context="Content/Applications/Button.Label/Verb"
      >
        Create application
      </translate>
    </button>
  </form>
</template>
