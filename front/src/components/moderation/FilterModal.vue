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
      content: t('components.moderation.FilterModal.message.success'),
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
    <h4
      v-if="type === 'artist'"
      class="header"
    >
      {{ $t('components.moderation.FilterModal.header.modal', {name: target?.name}) }}
    </h4>
    <div class="scrolling content">
      <div class="description">
        <div
          v-if="errors.length > 0"
          role="alert"
          class="ui negative message"
        >
          <h4 class="header">
            {{ $t('components.moderation.FilterModal.header.failure') }}
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
            {{ $t('components.moderation.FilterModal.warning.createFilter.listIntro') }}
          </p>
          <ul>
            <li>
              {{ $t('components.moderation.FilterModal.warning.createFilter.listItem1') }}
            </li>
            <li>
              {{ $t('components.moderation.FilterModal.warning.createFilter.listItem2') }}
            </li>
            <li>
              {{ $t('components.moderation.FilterModal.warning.createFilter.listItem3') }}
            </li>
            <li>
              {{ $t('components.moderation.FilterModal.warning.createFilter.listItem4') }}
            </li>
          </ul>
          <p>
            {{ $t('components.moderation.FilterModal.help.createFilter') }}
          </p>
        </template>
      </div>
    </div>
    <div class="actions">
      <button class="ui basic cancel button">
        {{ $t('components.moderation.FilterModal.button.cancel') }}
      </button>
      <button
        :class="['ui', 'success', {loading: isLoading}, 'button']"
        @click="hide"
      >
        {{ $t('components.moderation.FilterModal.button.hide') }}
      </button>
    </div>
  </semantic-modal>
</template>
