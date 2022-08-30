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
      <translate translate-context="Content/Library/Title">
        Current usage
      </translate>
    </h3>
    <div
      v-if="isLoading"
      :class="['ui', {'active': isLoading}, 'inverted', 'dimmer']"
    >
      <div class="ui text loader">
        <translate translate-context="Content/Library/Paragraph">
          Loading usage data…
        </translate>
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
          {{ progress }}%
        </div>
      </div>
      <div
        v-if="quotaStatus"
        class="label"
      >
        <translate
          translate-context="Content/Library/Paragraph"
          :translate-params="{max: humanSize(quotaStatus.max * 1000 * 1000), current: humanSize(quotaStatus.current * 1000 * 1000)}"
        >
          %{ current } used on %{ max } allowed
        </translate>
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
            <translate translate-context="Content/Library/Label">
              Pending files
            </translate>
          </div>
        </div>
        <div>
          <router-link
            class="ui basic primary tiny button"
            :to="{name: 'content.libraries.files', query: {q: compileTokens([{field: 'status', value: 'pending'}])}}"
          >
            <translate translate-context="Content/Library/Link/Verb">
              View files
            </translate>
          </router-link>

          <dangerous-button
            class="ui basic tiny button"
            :action="purgePendingFiles"
          >
            <translate translate-context="*/*/*/Verb">
              Purge
            </translate>
            <template #modal-header>
              <p>
                <translate translate-context="Popup/Library/Title">
                  Purge pending files?
                </translate>
              </p>
            </template>
            <template #modal-content>
              <p>
                <translate translate-context="Popup/Library/Paragraph">
                  Removes uploaded but yet to be processed tracks completely, adding the corresponding data to your quota.
                </translate>
              </p>
            </template>
            <template #modal-confirm>
              <div>
                <translate translate-context="*/*/*/Verb">
                  Purge
                </translate>
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
            <translate translate-context="Content/Library/Label">
              Skipped files
            </translate>
          </div>
        </div>
        <div>
          <router-link
            class="ui basic primary tiny button"
            :to="{name: 'content.libraries.files', query: {q: compileTokens([{field: 'status', value: 'skipped'}])}}"
          >
            <translate translate-context="Content/Library/Link/Verb">
              View files
            </translate>
          </router-link>
          <dangerous-button
            class="ui basic tiny button"
            :action="purgeSkippedFiles"
          >
            <translate translate-context="*/*/*/Verb">
              Purge
            </translate>
            <template #modal-header>
              <p>
                <translate translate-context="Popup/Library/Title">
                  Purge skipped files?
                </translate>
              </p>
            </template>
            <template #modal-content>
              <p>
                <translate translate-context="Popup/Library/Paragraph">
                  Removes uploaded tracks skipped during the import processes completely, adding the corresponding data to your quota.
                </translate>
              </p>
            </template>
            <template #modal-confirm>
              <div>
                <translate translate-context="*/*/*/Verb">
                  Purge
                </translate>
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
            <translate translate-context="Content/Library/Label">
              Errored files
            </translate>
          </div>
        </div>
        <div>
          <router-link
            class="ui basic primary tiny button"
            :to="{name: 'content.libraries.files', query: {q: compileTokens([{field: 'status', value: 'errored'}])}}"
          >
            <translate translate-context="Content/Library/Link/Verb">
              View files
            </translate>
          </router-link>
          <dangerous-button
            class="ui basic tiny button"
            :action="purgeErroredFiles"
          >
            <translate translate-context="*/*/*/Verb">
              Purge
            </translate>
            <template #modal-header>
              <p>
                <translate translate-context="Popup/Library/Title">
                  Purge errored files?
                </translate>
              </p>
            </template>
            <template #modal-content>
              <p>
                <translate translate-context="Popup/Library/Paragraph">
                  Removes uploaded tracks that could not be processed by the server completely, adding the corresponding data to your quota.
                </translate>
              </p>
            </template>
            <template #modal-confirm>
              <div>
                <translate translate-context="*/*/*/Verb">
                  Purge
                </translate>
              </div>
            </template>
          </dangerous-button>
        </div>
      </div>
    </div>
  </div>
</template>
