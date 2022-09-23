<script setup lang="ts">
import type { Library, BackendError, PrivacyLevel } from '~/types'

import { useI18n } from 'vue-i18n'
import { computed, ref } from 'vue'
import { useStore } from '~/store'

import axios from 'axios'

import useSharedLabels from '~/composables/locale/useSharedLabels'

const PRIVACY_LEVELS = ['me', 'instance', 'everyone'] as PrivacyLevel[]

interface Events {
  (e: 'updated', data: Library): void
  (e: 'created', data: Library): void
  (e: 'deleted'): void
}

interface Props {
  library?: Library
}

const emit = defineEmits<Events>()
const props = defineProps<Props>()

const { t } = useI18n()

const sharedLabels = useSharedLabels()
const store = useStore()

const labels = computed(() => ({
  descriptionPlaceholder: t('views.content.libraries.Form.placeholder.description'),
  namePlaceholder: t('views.content.libraries.Form.placeholder.name')
}))

const currentVisibilityLevel = ref(props.library?.privacy_level ?? 'me')
const currentDescription = ref(props.library?.description ?? '')
const currentName = ref(props.library?.name ?? '')

const errors = ref([] as string[])
const isLoading = ref(false)
const submit = async () => {
  isLoading.value = true

  try {
    const payload = {
      name: currentName.value,
      description: currentDescription.value,
      privacy_level: currentVisibilityLevel.value
    }

    const response = props.library
      ? await axios.patch(`libraries/${props.library.uuid}/`, payload)
      : await axios.post('libraries/', payload)

    if (props.library) emit('updated', response.data)
    else emit('created', response.data)

    store.commit('ui/addMessage', {
      content: props.library
        ? t('views.content.libraries.Form.message.libraryUpdated')
        : t('views.content.libraries.Form.message.libraryCreated'),
      date: new Date()
    })
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}

const remove = async () => {
  isLoading.value = true

  try {
    await axios.delete(`libraries/${props.library?.uuid}/`)
    emit('deleted')
    store.commit('ui/addMessage', {
      content: t('views.content.libraries.Form.message.libraryDeleted'),
      date: new Date()
    })
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}
</script>

<template>
  <form
    class="ui form"
    @submit.prevent="submit"
  >
    <p v-if="!library">
      {{ $t('views.content.libraries.Form.description.library') }}
    </p>
    <div
      v-if="errors.length > 0"
      role="alert"
      class="ui negative message"
    >
      <h4 class="header">
        {{ $t('views.content.libraries.Form.header.failure') }}
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
    <div class="required field">
      <label for="current-name">{{ $t('views.content.libraries.Form.label.name') }}</label>
      <input
        id="current-name"
        v-model="currentName"
        name="name"
        :placeholder="labels.namePlaceholder"
        required
        maxlength="100"
      >
    </div>
    <div class="field">
      <label for="current-description">{{ $t('views.content.libraries.Form.label.description') }}</label>
      <textarea
        id="current-description"
        v-model="currentDescription"
        :placeholder="labels.descriptionPlaceholder"
        maxlength="2000"
      />
    </div>
    <div class="field">
      <label for="visibility-level">{{ $t('views.content.libraries.Form.label.visibility') }}</label>
      <p>
        {{ $t('views.content.libraries.Form.description.visibility') }}
      </p>
      <select
        id="visibility-level"
        v-model="currentVisibilityLevel"
        class="ui dropdown"
      >
        <option
          v-for="c in PRIVACY_LEVELS"
          :key="c"
          :value="c"
        >
          {{ sharedLabels.fields.privacy_level.choices[c] }}
        </option>
      </select>
    </div>
    <button
      class="ui submit button"
      type="submit"
    >
      <span
        v-if="library"
      >
        {{ $t('views.content.libraries.Form.button.update') }}
      </span>
      <span
        v-else
      >
        {{ $t('views.content.libraries.Form.button.create') }}
      </span>
    </button>
    <dangerous-button
      v-if="library"
      type="button"
      class="ui right floated basic danger button"
      @confirm="remove"
    >
      {{ $t('views.content.libraries.Form.button.delete') }}
      <template #modal-header>
        <p>
          {{ $t('views.content.libraries.Form.modal.delete.header') }}
        </p>
      </template>
      <template #modal-content>
        <p>
          {{ $t('views.content.libraries.Form.modal.delete.content.warning') }}
        </p>
      </template>
      <template #modal-confirm>
        <div>
          {{ $t('views.content.libraries.Form.button.confirm') }}
        </div>
      </template>
    </dangerous-button>
  </form>
</template>
