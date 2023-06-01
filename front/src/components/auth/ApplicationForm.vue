<script setup lang="ts">
import type { BackendError, Application } from '~/types'

import axios from 'axios'
import { ref, reactive, computed } from 'vue'
import { computedEager } from '@vueuse/core'
import { useI18n } from 'vue-i18n'
import { uniq } from 'lodash-es'

import useScopes from '~/composables/auth/useScopes'

interface Events {
  (e: 'updated', application: Application): void
  (e: 'created', application: Application): void
}

interface Props {
  app?: Application | null
  defaults?: Partial<Application>
}

const emit = defineEmits<Events>()
const props = withDefaults(defineProps<Props>(), {
  app: null,
  defaults: () => ({})
})

const { t } = useI18n()
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
    const isUpdating = props.app !== null
    const request = isUpdating
      ? () => axios.patch(`oauth/apps/${props.app?.client_id}/`, fields)
      : () => axios.post('oauth/apps/', fields)

    const response = await request()

    if (isUpdating) emit('updated', response.data as Application)
    else emit('created', response.data as Application)
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}

const scopeArray = computed({
  get: () => fields.scopes.trim().split(' '),
  set: (scopes: string[]) => (fields.scopes = uniq(scopes).join(' '))
})

const allScopesSelected = (parent: typeof allScopes['value'][number]) => {
  const scopes = new Set(scopeArray.value)
  return parent.children.every(child => scopes.has(child.id))
}

const toggleAllScopes = (parent: typeof allScopes['value'][number]) => {
  const scopes = new Set(scopeArray.value)

  const allScopesSelected = parent.children.every(child => scopes.has(child.id))
  for (const child of parent.children) {
    const action = allScopesSelected
      ? 'delete'
      : 'add'

    scopes[action](child.id)
  }

  scopeArray.value = [...scopes]
}

const scopeParents = computedEager(() => [
  {
    id: 'read',
    label: t('components.auth.ApplicationForm.label.scopes.read.label'),
    description: t('components.auth.ApplicationForm.label.scopes.read.description'),
    value: scopeArray.value.includes('read')
  },
  {
    id: 'write',
    label: t('components.auth.ApplicationForm.label.scopes.write.label'),
    description: t('components.auth.ApplicationForm.label.scopes.write.description'),
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
        {{ $t('components.auth.ApplicationForm.header.failure') }}
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
      <label for="application-name">{{ $t('components.auth.ApplicationForm.label.name') }}</label>
      <input
        id="application-name"
        v-model="fields.name"
        name="name"
        required
        type="text"
      >
    </div>
    <div class="ui field">
      <label for="redirect-uris">{{ $t('components.auth.ApplicationForm.label.redirectUri') }}</label>
      <input
        id="redirect-uris"
        v-model="fields.redirect_uris"
        name="redirect_uris"
        type="text"
      >
      <p class="help">
        {{ $t('components.auth.ApplicationForm.help.redirectUri') }}
      </p>
    </div>
    <div class="ui field">
      <label>{{ $t('components.auth.ApplicationForm.label.scopes.label') }}</label>
      <p>
        {{ $t('components.auth.ApplicationForm.label.scopes.description') }}
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
              :checked="allScopesSelected(parent)"
              type="checkbox"
              @input="toggleAllScopes(parent)"
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
      <span v-if="app !== null">
        {{ $t('components.auth.ApplicationForm.button.update') }}
      </span>
      <span v-else>
        {{ $t('components.auth.ApplicationForm.button.create') }}
      </span>
    </button>
  </form>
</template>
