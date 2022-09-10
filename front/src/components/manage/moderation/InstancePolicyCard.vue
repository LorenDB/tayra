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
        Enabled
      </template>
      <template v-if="!object.is_active">
        <i class="pause icon" />
        Paused
      </template>
    </p>
    <div>
      <p><strong>Rule</strong></p>
      <p v-if="object.block_all">
        <i class="ban icon" />
        Block everything
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
            Mute activity
          </div>
        </div>
        <div
          v-if="object.silence_notifications"
          class="ui item"
        >
          <i class="bell icon" />
          <div class="content">
            Mute notifications
          </div>
        </div>
        <div
          v-if="object.reject_media"
          class="ui item"
        >
          <i class="file icon" />
          <div class="content">
            Reject media
          </div>
        </div>
      </div>
    </div>
    <div v-if="summary">
      <div class="ui hidden divider" />
      <p><strong>Reason</strong></p>
      <sanitized-html :html="summary" />
    </div>
    <div class="ui hidden divider" />
    <button
      class="ui right floated labeled icon button"
      @click="emit('update')"
    >
      <i class="edit icon" />
      Edit
    </button>
  </div>
</template>
