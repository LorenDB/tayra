<script setup lang="ts">
import type { ImportStatus } from '~/types'

import { compileTokens } from '~/utils/search'
import { humanSize } from '~/utils/filters'
import { computed, ref } from 'vue'

import useErrorHandler from '~/composables/useErrorHandler'

import axios from 'axios'

const quotaStatus = ref()
const progress = computed(() => !quotaStatus.value
  ? 0
  : Math.min(quotaStatus.value.current * 100 / quotaStatus.value.max, 100)
)

const isLoading = ref(false)
const fetchData = async () => {
  isLoading.value = true

  try {
    const response = await axios.get('users/me/')
    quotaStatus.value = response.data.quota_status
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoading.value = false
}

fetchData()

const purge = async (status: ImportStatus) => {
  try {
    await axios.post('uploads/action/', {
      action: 'delete',
      objects: 'all',
      filters: { import_status: status }
    })

    fetchData()
  } catch (error) {
    useErrorHandler(error as Error)
  }
}

const purgeSkippedFiles = () => purge('skipped')
const purgePendingFiles = () => purge('pending')
const purgeErroredFiles = () => purge('errored')
</script>

<template>
  <div class="ui segment">
    <h3 class="ui header">
      {{ $t('views.content.libraries.Quota.header.currentUsage') }}
    </h3>
    <div
      v-if="isLoading"
      :class="['ui', {'active': isLoading}, 'inverted', 'dimmer']"
    >
      <div class="ui text loader">
        {{ $t('views.content.libraries.Quota.loading.currentUsage') }}
      </div>
    </div>
    <div
      :class="['ui', {'success': progress < 60}, {'warning': progress >= 60 && progress < 96}, {'error': progress >= 95}, 'progress']"
      data-percent="progress"
    >
      <div
        class="bar"
        :style="{width: `${progress}%`}"
      >
        <div class="progress">
          {{ $t('views.content.libraries.Quota.label.percentUsed', {progress: progress}) }}
        </div>
      </div>
      <div
        v-if="quotaStatus"
        class="label"
      >
        {{ $t('views.content.libraries.Quota.label.currentUsage', {max: humanSize(quotaStatus.max * 1000 * 1000), current: humanSize(quotaStatus.current * 1000 * 1000)}) }}
      </div>
    </div>
    <div class="ui hidden divider" />
    <div
      v-if="quotaStatus"
      class="ui stackable three column grid"
    >
      <div
        v-if="quotaStatus.pending > 0"
        class="column"
      >
        <div class="ui tiny warning statistic">
          <div class="value">
            {{ humanSize(quotaStatus.pending * 1000 * 1000) }}
          </div>
          <div class="label">
            {{ $t('views.content.libraries.Quota.label.pending') }}
          </div>
        </div>
        <div>
          <router-link
            class="ui basic primary tiny button"
            :to="{name: 'content.libraries.files', query: {q: compileTokens([{field: 'status', value: 'pending'}])}}"
          >
            {{ $t('views.content.libraries.Quota.link.viewFiles') }}
          </router-link>

          <dangerous-button
            class="ui basic tiny button"
            :action="purgePendingFiles"
          >
            {{ $t('views.content.libraries.Quota.button.purge') }}
            <template #modal-header>
              <p>
                {{ $t('views.content.libraries.Quota.modal.purgePending.header') }}
              </p>
            </template>
            <template #modal-content>
              <p>
                {{ $t('views.content.libraries.Quota.modal.purgePending.content.description') }}
              </p>
            </template>
            <template #modal-confirm>
              <div>
                {{ $t('views.content.libraries.Quota.button.purge') }}
              </div>
            </template>
          </dangerous-button>
        </div>
      </div>
      <div
        v-if="quotaStatus.skipped > 0"
        class="column"
      >
        <div class="ui tiny statistic">
          <div class="value">
            {{ humanSize(quotaStatus.skipped * 1000 * 1000) }}
          </div>
          <div class="label">
            {{ $t('views.content.libraries.Quota.label.skipped') }}
          </div>
        </div>
        <div>
          <router-link
            class="ui basic primary tiny button"
            :to="{name: 'content.libraries.files', query: {q: compileTokens([{field: 'status', value: 'skipped'}])}}"
          >
            {{ $t('views.content.libraries.Quota.link.viewFiles') }}
          </router-link>
          <dangerous-button
            class="ui basic tiny button"
            :action="purgeSkippedFiles"
          >
            {{ $t('views.content.libraries.Quota.button.purge') }}
            <template #modal-header>
              <p>
                {{ $t('views.content.libraries.Quota.modal.purgeSkipped.header') }}
              </p>
            </template>
            <template #modal-content>
              <p>
                {{ $t('views.content.libraries.Quota.modal.purgeSkipped.content.description') }}
              </p>
            </template>
            <template #modal-confirm>
              <div>
                {{ $t('views.content.libraries.Quota.button.purge') }}
              </div>
            </template>
          </dangerous-button>
        </div>
      </div>
      <div
        v-if="quotaStatus.errored > 0"
        class="column"
      >
        <div class="ui tiny danger statistic">
          <div class="value">
            {{ humanSize(quotaStatus.errored * 1000 * 1000) }}
          </div>
          <div class="label">
            {{ $t('views.content.libraries.Quota.label.errored') }}
          </div>
        </div>
        <div>
          <router-link
            class="ui basic primary tiny button"
            :to="{name: 'content.libraries.files', query: {q: compileTokens([{field: 'status', value: 'errored'}])}}"
          >
            {{ $t('views.content.libraries.Quota.link.viewFiles') }}
          </router-link>
          <dangerous-button
            class="ui basic tiny button"
            :action="purgeErroredFiles"
          >
            {{ $t('views.content.libraries.Quota.button.purge') }}
            <template #modal-header>
              <p>
                {{ $t('views.content.libraries.Quota.modal.purgeErrored.header') }}
              </p>
            </template>
            <template #modal-content>
              <p>
                {{ $t('views.content.libraries.Quota.modal.purgeErrored.content.description') }}
              </p>
            </template>
            <template #modal-confirm>
              <div>
                {{ $t('views.content.libraries.Quota.button.purge') }}
              </div>
            </template>
          </dangerous-button>
        </div>
      </div>
    </div>
  </div>
</template>
