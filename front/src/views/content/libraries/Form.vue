<script setup lang="ts">
import type { Library, BackendError, PrivacyLevel } from '~/types'

import { useGettext } from 'vue3-gettext'
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

const { $pgettext } = useGettext()

const sharedLabels = useSharedLabels()
const store = useStore()

const labels = computed(() => ({
  descriptionPlaceholder: $pgettext('Content/Library/Input.Placeholder', 'This library contains my personal music, I hope you like it.'),
  namePlaceholder: $pgettext('Content/Library/Input.Placeholder', 'My awesome library')
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
        ? $pgettext('Content/Library/Message', 'Library updated')
        : $pgettext('Content/Library/Message', 'Library created'),
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
      content: $pgettext('Content/Library/Message', 'Library deleted'),
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
      <translate translate-context="Content/Library/Paragraph">
        Libraries help you organize and share your music collections. You can upload your own music collection to Funkwhale and share it with your friends and family.
      </translate>
    </p>
    <div
      v-if="errors.length > 0"
      role="alert"
      class="ui negative message"
    >
      <h4 class="header">
        <translate translate-context="Content/*/Error message.Title">
          Error
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
    <div class="required field">
      <label for="current-name"><translate translate-context="*/*/*/Noun">Name</translate></label>
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
      <label for="current-description"><translate translate-context="*/*/*/Noun">Description</translate></label>
      <textarea
        id="current-description"
        v-model="currentDescription"
        :placeholder="labels.descriptionPlaceholder"
        maxlength="2000"
      />
    </div>
    <div class="field">
      <label for="visibility-level"><translate translate-context="*/*/*">Visibility</translate></label>
      <p>
        <translate translate-context="Content/Library/Paragraph">
          You are able to share your library with other people, regardless of its visibility.
        </translate>
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
      <translate
        v-if="library"
        translate-context="Content/Library/Button.Label/Verb"
      >
        Update library
      </translate>
      <translate
        v-else
        translate-context="Content/Library/Button.Label/Verb"
      >
        Create library
      </translate>
    </button>
    <dangerous-button
      v-if="library"
      type="button"
      class="ui right floated basic danger button"
      @confirm="remove"
    >
      <translate translate-context="*/*/*/Verb">
        Delete
      </translate>
      <template #modal-header>
        <p>
          <translate translate-context="Popup/Library/Title">
            Delete this library?
          </translate>
        </p>
      </template>
      <template #modal-content>
        <p>
          <translate translate-context="Popup/Library/Paragraph">
            The library and all its tracks will be deleted. This can not be undone.
          </translate>
        </p>
      </template>
      <template #modal-confirm>
        <div>
          <translate translate-context="Popup/Library/Button.Label/Verb">
            Delete library
          </translate>
        </div>
      </template>
    </dangerous-button>
  </form>
</template>
