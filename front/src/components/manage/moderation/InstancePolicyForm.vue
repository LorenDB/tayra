<script setup lang="ts">
import type { BackendError, InstancePolicy } from '~/types'

import { computed, ref, reactive } from 'vue'
import { whenever } from '@vueuse/core'
import { useI18n } from 'vue-i18n'

import axios from 'axios'

interface Events {
  (e: 'save', data: InstancePolicy): void
  (e: 'delete'): void
  (e: 'cancel'): void
}

interface Props {
  type: string
  target: string
  object?: InstancePolicy | null
}

const emit = defineEmits<Events>()
const props = withDefaults(defineProps<Props>(), {
  object: null
})

const { t } = useI18n()

const labels = computed(() => ({
  summaryHelp: t('components.manage.moderation.InstancePolicyForm.summaryHelp'),
  isActiveHelp: t('components.manage.moderation.InstancePolicyForm.isActiveHelp'),
  blockAllHelp: t('components.manage.moderation.InstancePolicyForm.blockAllHelp'),
  silenceActivity: {
    help: t('components.manage.moderation.InstancePolicyForm.silenceActivityHelp'),
    label: t('components.manage.moderation.InstancePolicyForm.silenceActivityLabel')
  },
  silenceNotifications: {
    help: t('components.manage.moderation.InstancePolicyForm.silenceNotificationsHelp'),
    label: t('components.manage.moderation.InstancePolicyForm.silenceNotificationsLabel')
  },
  rejectMedia: {
    help: t('components.manage.moderation.InstancePolicyForm.rejectMediaHelp'),
    label: t('components.manage.moderation.InstancePolicyForm.rejectMediaLabel')
  }
}))

const current = reactive({
  summary: props.object?.summary ?? '',
  isActive: props.object?.is_active ?? true,
  blockAll: props.object?.block_all ?? true,
  silenceActivity: props.object?.silence_activity ?? false,
  silenceNotifications: props.object?.silence_notifications ?? false,
  rejectMedia: props.object?.reject_media ?? false
})

const fieldConfig = [
  // TODO: We hide those until we actually have the related features implemented :)
  // { id: 'silenceActivity', icon: 'feed' },
  // { id: 'silenceNotifications', icon: 'bell' },
  { id: 'rejectMedia', icon: 'file' }
] as const

whenever(() => current.silenceNotifications, () => (current.blockAll = false))
whenever(() => current.silenceActivity, () => (current.blockAll = false))
whenever(() => current.rejectMedia, () => (current.blockAll = false))
whenever(() => current.blockAll, () => {
  for (const config of fieldConfig) {
    current[config.id] = false
  }
})

const isLoading = ref(false)
const errors = ref([] as string[])
const createOrUpdate = async () => {
  isLoading.value = true
  errors.value = []

  try {
    const data = {
      summary: current.summary,
      is_active: current.isActive,
      block_all: current.blockAll,
      silence_activity: current.silenceActivity,
      silence_notifications: current.silenceNotifications,
      reject_media: current.rejectMedia,
      target: {
        type: props.type,
        id: props.target
      }
    }

    const response = props.object
      ? await axios.patch(`manage/moderation/instance-policies/${props.object.id}/`, data)
      : await axios.post('manage/moderation/instance-policies/', data)

    emit('save', response.data)
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}

const remove = async () => {
  isLoading.value = true
  errors.value = []

  try {
    await axios.delete(`manage/moderation/instance-policies/${props.object?.id}/`)
    emit('delete')
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}
</script>

<template>
  <form
    class="ui form"
    @submit.prevent="createOrUpdate"
  >
    <h3 class="ui header">
      <span
        v-if="object"
      >
        {{ $t('components.manage.moderation.InstancePolicyForm.editRuleHeader') }}
      </span>
      <span
        v-else
      >
        {{ $t('components.manage.moderation.InstancePolicyForm.addRuleHeader') }}
      </span>
    </h3>
    <div
      v-if="errors && errors.length > 0"
      role="alert"
      class="ui negative message"
    >
      <h4 class="header">
        {{ $t('components.manage.moderation.InstancePolicyForm.createRuleFailureHeader') }}
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
      v-if="object"
      class="field"
    >
      <div class="ui toggle checkbox">
        <input
          id="policy-is-active"
          v-model="current.isActive"
          type="checkbox"
        >
        <label for="policy-is-active">
          <span
            v-if="current.isActive"
          >{{ $t('components.manage.moderation.InstancePolicyForm.policyEnabled') }}</span>
          <span
            v-else
          >{{ $t('components.manage.moderation.InstancePolicyForm.policyDisabled') }}</span>
          <tooltip :content="labels.isActiveHelp" />
        </label>
      </div>
    </div>
    <div class="field">
      <label for="policy-summary">
        {{ $t('components.manage.moderation.InstancePolicyForm.policyReasonLabel') }}
        <tooltip :content="labels.summaryHelp" />
      </label>
      <textarea
        id="policy-summary"
        v-model="current.summary"
        name="policy-summary"
        rows="5"
      />
    </div>
    <div class="field">
      <div class="ui toggle checkbox">
        <input
          id="policy-is-active"
          v-model="current.blockAll"
          type="checkbox"
        >
        <label for="policy-is-active">
          {{ $t('components.manage.moderation.InstancePolicyForm.blockAllLabel') }}
          <tooltip :content="labels.blockAllHelp" />
        </label>
      </div>
    </div>
    <div class="ui horizontal divider">
      {{ $t('components.manage.moderation.InstancePolicyForm.customizeRuleMessage') }}
    </div>
    <div
      v-for="(config, key) in fieldConfig"
      :key="key"
      :class="['field']"
    >
      <div class="ui toggle checkbox">
        <input
          :id="'policy-' + config.id"
          v-model="current[config.id]"
          type="checkbox"
        >
        <label :for="'policy-' + config.id">
          <i :class="[config.icon, 'icon']" />
          {{ labels[config.id].label }}
          <tooltip :content="labels[config.id].help" />
        </label>
      </div>
    </div>
    <div class="ui hidden divider" />
    <button
      class="ui basic left floated button"
      @click.prevent="emit('cancel')"
    >
      {{ $t('components.manage.moderation.InstancePolicyForm.cancelButton') }}
    </button>
    <button
      :class="['ui', 'right', 'floated', 'success', {'disabled loading': isLoading}, 'button']"
      :disabled="isLoading"
    >
      <span
        v-if="object"
      >
        {{ $t('components.manage.moderation.InstancePolicyForm.updateButton') }}
      </span>
      <span
        v-else
      >
        {{ $t('components.manage.moderation.InstancePolicyForm.createButton') }}
      </span>
    </button>
    <dangerous-button
      v-if="object"
      class="ui right floated basic danger button"
      @confirm="remove"
    >
      {{ $t('components.manage.moderation.InstancePolicyForm.deleteButton') }}
      <template #modal-header>
        <p>
          {{ $t('components.manage.moderation.InstancePolicyForm.deleteRuleModalHeader') }}
        </p>
      </template>
      <template #modal-content>
        <p>
          {{ $t('components.manage.moderation.InstancePolicyForm.deleteRuleModalMessage') }}
        </p>
      </template>
      <template #modal-confirm>
        <div>
          {{ $t('components.manage.moderation.InstancePolicyForm.deleteRuleModalConfirm') }}
        </div>
      </template>
    </dangerous-button>
  </form>
</template>
