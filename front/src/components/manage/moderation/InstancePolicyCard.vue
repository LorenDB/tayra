<script setup lang="ts">
import type { InstancePolicy } from '~/types'

import useMarkdown from '~/composables/useMarkdown'

interface Events {
  (e: 'update'): void
}

interface Props {
  object: InstancePolicy
}

const emit = defineEmits<Events>()
const props = defineProps<Props>()

const summary = useMarkdown(() => props.object.summary)
</script>

<template>
  <div>
    <slot />
    <p>
      <i class="clock outline icon" /><human-date :date="object.creation_date" /> &nbsp;
      <i class="user icon" />{{ object.actor }}  &nbsp;
      <template v-if="object.is_active">
        <i class="play icon" />
        {{ $t('components.manage.moderation.InstancePolicyCard.status.enabled') }}
      </template>
      <template v-if="!object.is_active">
        <i class="pause icon" />
        {{ $t('components.manage.moderation.InstancePolicyCard.status.paused') }}
      </template>
    </p>
    <div>
      <p><strong>{{ $t('components.manage.moderation.InstancePolicyCard.header.rule') }}</strong></p>
      <p v-if="object.block_all">
        <i class="ban icon" />
        {{ $t('components.manage.moderation.InstancePolicyCard.label.blockAll') }}
      </p>
      <div
        v-else
        class="ui list"
      >
        <div
          v-if="object.silence_activity"
          class="ui item"
        >
          <i class="feed icon" />
          <div class="content">
            {{ $t('components.manage.moderation.InstancePolicyCard.label.muteActivity') }}
          </div>
        </div>
        <div
          v-if="object.silence_notifications"
          class="ui item"
        >
          <i class="bell icon" />
          <div class="content">
            {{ $t('components.manage.moderation.InstancePolicyCard.label.muteNotifications') }}
          </div>
        </div>
        <div
          v-if="object.reject_media"
          class="ui item"
        >
          <i class="file icon" />
          <div class="content">
            {{ $t('components.manage.moderation.InstancePolicyCard.label.rejectMedia') }}
          </div>
        </div>
      </div>
    </div>
    <div v-if="summary">
      <div class="ui hidden divider" />
      <p><strong>{{ $t('components.manage.moderation.InstancePolicyCard.label.reason') }}</strong></p>
      <sanitized-html :html="summary" />
    </div>
    <div class="ui hidden divider" />
    <button
      class="ui right floated labeled icon button"
      @click="emit('update')"
    >
      <i class="edit icon" />
      {{ $t('components.manage.moderation.InstancePolicyCard.button.edit') }}
    </button>
  </div>
</template>
