<script setup lang="ts">
import type { BackendError } from '~/types'

import axios from 'axios'

import { computed, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useStore } from '~/store'

import SemanticModal from '~/components/semantic/Modal.vue'
import useLogger from '~/composables/useLogger'

const logger = useLogger()
const { t } = useI18n()

const store = useStore()
const show = computed({
  get: () => store.state.moderation.showFilterModal,
  set: (value) => {
    store.commit('moderation/showFilterModal', value)
    errors.value = []
  }
})

const type = computed(() => store.state.moderation.filterModalTarget.type)
const target = computed(() => store.state.moderation.filterModalTarget.target)

const errors = ref([] as string[])
const isLoading = ref(false)

const hide = async () => {
  isLoading.value = true

  const payload = {
    target: {
      type: type.value,
      id: target.value?.id
    }
  }

  try {
    const response = await axios.post('moderation/content-filters/', payload)
    logger.info(`Successfully hidden ${type.value} ${target.value?.id}`)
    show.value = false
    store.state.moderation.lastUpdate = new Date()
    store.commit('moderation/contentFilter', response.data)
    store.commit('ui/addMessage', {
      content: t('Content filter successfully added'),
      date: new Date()
    })
  } catch (error) {
    logger.error(`Error while hiding ${type.value} ${target.value?.id}`)
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}
</script>

<template>
  <semantic-modal v-model:show="show">
    <h4 class="header">
      <translate
        v-if="type === 'artist'"

        :translate-params="{name: target?.name}"
      >
        Do you want to hide content from artist "%{ name }"?
      </translate>
    </h4>
    <div class="scrolling content">
      <div class="description">
        <div
          v-if="errors.length > 0"
          role="alert"
          class="ui negative message"
        >
          <h4 class="header">
            Error while creating filter
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
        <template v-if="type === 'artist'">
          <p>
            You will not see tracks, albums and user activity linked to this artist any more:
          </p>
          <ul>
            <li>
              In other users favorites and listening history
            </li>
            <li>
              In "Recently added" widget
            </li>
            <li>
              In artists and album listings
            </li>
            <li>
              In radio suggestions
            </li>
          </ul>
          <p>
            You can manage and update your filters any time from your account settings.
          </p>
        </template>
      </div>
    </div>
    <div class="actions">
      <button class="ui basic cancel button">
        Cancel
      </button>
      <button
        :class="['ui', 'success', {loading: isLoading}, 'button']"
        @click="hide"
      >
        Hide content
      </button>
    </div>
  </semantic-modal>
</template>
