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
  summaryHelp: t("Explain why you're applying this policy: this will help you remember why you added this rule. Depending on your pod configuration, this may be displayed publicly to help users understand the moderation rules in place."),
  isActiveHelp: t('Use this setting to temporarily enable/disable the policy without completely removing it.'),
  blockAllHelp: t('Block everything from this account or domain. This will prevent any interaction with the entity, and purge related content (uploads, libraries, follows, etc.)'),
  silenceActivity: {
    help: t('Hide account or domain content, except from followers.'),
    label: t('Mute activity')
  },
  silenceNotifications: {
    help: t('Prevent account or domain from triggering notifications, except from followers.'),
    label: t('Mute notifications')
  },
  rejectMedia: {
    help: t('Do not download any media file (audio, album cover, account avatar…) from this account or domain. This will purge existing content as well.'),
    label: t('Reject media')
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
      <translate
        v-if="object"
      >
        Edit moderation rule
      </translate>
      <translate
        v-else
      >
        Add a new moderation rule
      </translate>
    </h3>
    <div
      v-if="errors && errors.length > 0"
      role="alert"
      class="ui negative message"
    >
      <h4 class="header">
        Error while creating rule
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
          <translate
            v-if="current.isActive"
          >Enabled</translate>
          <translate
            v-else
          >Disabled</translate>
          <tooltip :content="labels.isActiveHelp" />
        </label>
      </div>
    </div>
    <div class="field">
      <label for="policy-summary">
        Reason
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
          Block everything
          <tooltip :content="labels.blockAllHelp" />
        </label>
      </div>
    </div>
    <div class="ui horizontal divider">
      Or customize your rule
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
      Cancel
    </button>
    <button
      :class="['ui', 'right', 'floated', 'success', {'disabled loading': isLoading}, 'button']"
      :disabled="isLoading"
    >
      <translate
        v-if="object"
      >
        Update
      </translate>
      <translate
        v-else
      >
        Create
      </translate>
    </button>
    <dangerous-button
      v-if="object"
      class="ui right floated basic danger button"
      @confirm="remove"
    >
      Delete
      <template #modal-header>
        <p>
          Delete this moderation rule?
        </p>
      </template>
      <template #modal-content>
        <p>
          This action is irreversible.
        </p>
      </template>
      <template #modal-confirm>
        <div>
          Delete moderation rule
        </div>
      </template>
    </dangerous-button>
  </form>
</template>
