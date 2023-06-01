<script setup lang="ts">
import type { BackendError } from '~/types'

import axios from 'axios'
import ReportCategoryDropdown from '~/components/moderation/ReportCategoryDropdown.vue'
import SemanticModal from '~/components/semantic/Modal.vue'
import { computed, ref, watchEffect } from 'vue'
import { useStore } from '~/store'
import { useI18n } from 'vue-i18n'

interface ReportType {
  anonymous: boolean
  type: string
}

const store = useStore()
const target = computed(() => store.state.moderation.reportModalTarget)

const forward = ref(false)
const summary = ref('')
const category = ref('')
const submitterEmail = ref('')

const reportTypes = ref([] as ReportType[])
const allowedCategories = computed(() => {
  if (store.state.auth.authenticated) {
    return []
  }

  return reportTypes.value
    .filter((type) => type.anonymous === true)
    .map((type) => type.type)
})

const canSubmit = computed(() => store.state.auth.authenticated || allowedCategories.value.length > 0)

const targetDomain = computed(() => {
  if (!target.value._obj) {
    return
  }

  const fid = target.value.type === 'channel' && target.value._obj.actor
    ? target.value._obj.actor.fid
    : target.value._obj.fid

  return !fid
    ? store.getters['instance/domain']
    : new URL(fid).hostname
})

const isLocal = computed(() => store.getters['instance/domain'] === targetDomain.value)

const errors = ref([] as string[])

const show = computed({
  get: () => store.state.moderation.showReportModal,
  set: (value: boolean) => {
    store.commit('moderation/showReportModal', value)
    errors.value = []
  }
})

const isLoading = ref(false)

// TODO (wvffle): MOVE ALL use*() METHODS SOMEWHERE TO THE TOP
const { t } = useI18n()

const submit = async () => {
  isLoading.value = true

  const payload = {
    target: { ...target.value, _obj: undefined },
    summary: summary.value,
    type: category.value,
    forward: forward.value,
    submitter_email: !store.state.auth.authenticated
      ? submitterEmail.value
      : undefined
  }

  try {
    const response = await axios.post('moderation/reports/', payload)
    show.value = false

    store.commit('moderation/contentFilter', response.data)
    store.commit('ui/addMessage', {
      content: t('components.moderation.ReportModal.message.submissionSuccess'),
      date: new Date()
    })

    summary.value = ''
    category.value = ''
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}

const isLoadingReportTypes = ref(false)
watchEffect(async () => {
  if (!store.state.moderation.showReportModal || store.state.auth.authenticated) {
    return
  }

  isLoadingReportTypes.value = true

  try {
    const response = await axios.get('instance/nodeinfo/2.0/')
    reportTypes.value = response.data.metadata.reportTypes ?? []
  } catch (error) {
    store.commit('ui/addMessage', {
      content: t('components.moderation.ReportModal.error.nodeinfoFetch', { error: `${error}` }),
      date: new Date()
    })
  }

  isLoadingReportTypes.value = false
})
</script>

<template>
  <semantic-modal v-model:show="show">
    <h2
      v-if="target"
      class="ui header"
    >
      {{ $t('components.moderation.ReportModal.header.modal') }}
      <div class="ui sub header">
        {{ target.typeLabel }}
        <span class="middle hyphen symbol" />
        {{ target.label }}
      </div>
    </h2>
    <div class="scrolling content">
      <div class="description">
        <div
          v-if="errors.length > 0"
          role="alert"
          class="ui negative message"
        >
          <h4 class="header">
            {{ $t('components.moderation.ReportModal.header.submissionFailure') }}
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
      </div>
      <p>
        {{ $t('components.moderation.ReportModal.description.modal') }}
      </p>
      <form
        v-if="canSubmit"
        id="report-form"
        class="ui form"
        @submit.prevent="submit"
      >
        <div class="fields">
          <report-category-dropdown
            v-model="category"
            class="ui required eight wide field"
            :required="true"
            :empty="true"
            :restrict-to="allowedCategories"
            :label="true"
          />
          <div
            v-if="!$store.state.auth.authenticated"
            class="ui eight wide required field"
          >
            <label for="report-submitter-email">
              {{ $t('components.moderation.ReportModal.label.email') }}
            </label>
            <input
              id="report-submitter-email"
              v-model="submitterEmail"
              type="email"
              name="report-submitter-email"
              required
            >
            <p>
              {{ $t('components.moderation.ReportModal.description.email') }}
            </p>
          </div>
        </div>
        <div class="ui field">
          <label for="report-summary">
            {{ $t('components.moderation.ReportModal.label.message') }}
          </label>
          <p>
            {{ $t('components.moderation.ReportModal.description.message') }}
          </p>
          <content-form
            v-model="summary"
            field-id="report-summary"
            :rows="8"
          />
        </div>
        <div
          v-if="!isLocal"
          class="ui field"
        >
          <div class="ui checkbox">
            <input
              id="report-forward"
              v-model="forward"
              type="checkbox"
            >
            <label for="report-forward">
              <strong>
                {{ $t('components.moderation.ReportModal.label.forwardToDomain', {domain: targetDomain}) }}
              </strong>
              <p>
                {{ $t('components.moderation.ReportModal.description.forwardToDomain') }}
              </p>
            </label>
          </div>
        </div>
        <div class="ui hidden divider" />
      </form>
      <div
        v-else-if="isLoadingReportTypes"
        class="ui inline active loader"
      />
      <div
        v-else
        role="alert"
        class="ui warning message"
      >
        <h4 class="header">
          {{ $t('components.moderation.ReportModal.header.disabled') }}
        </h4>
      </div>
    </div>
    <div class="actions">
      <button class="ui basic cancel button">
        {{ $t('components.moderation.ReportModal.button.cancel') }}
      </button>
      <button
        v-if="canSubmit"
        :class="['ui', 'success', {loading: isLoading}, 'button']"
        type="submit"
        form="report-form"
      >
        {{ $t('components.moderation.ReportModal.button.submit') }}
      </button>
    </div>
  </semantic-modal>
</template>
