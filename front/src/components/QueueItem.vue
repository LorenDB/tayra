<script setup lang="ts">
import type { QueueItemSource } from '~/types'

import time from '~/utils/time'

interface Events {
  (e: 'play', index: number): void
  (e: 'remove', index: number): void
}

interface Props {
  source: QueueItemSource
  index: number
}

defineEmits<Events>()
defineProps<Props>()
</script>

<template>
  <div
    class="queue-item"
    tabindex="0"
  >
    <div class="handle">
      <i class="grip lines icon" />
    </div>
    <div
      class="image-cell"
      @click="$emit('play', index)"
    >
      <img
        class="ui mini image"
        alt=""
        :src="source.coverUrl"
      >
    </div>
    <div @click="$emit('play', index)">
      <button
        class="title reset ellipsis"
        :title="source.title"
        :aria-label="source.labels.selectTrack"
      >
        <strong>{{ source.title }}</strong><br>
        <span>
          {{ source.artistName }}
        </span>
      </button>
    </div>
    <div class="duration-cell">
      <template v-if="source.sources.length > 0">
        {{ time.parse(Math.round(source.sources[0].duration ?? 0)) }}
      </template>
    </div>
    <div class="controls">
      <button
        v-if="$store.state.auth.authenticated"
        :aria-label="source.labels.favorite"
        :title="source.labels.favorite"
        class="ui really basic circular icon button"
        @click.stop="$store.dispatch('favorites/toggle', source.id)"
      >
        <i
          :class="$store.getters['favorites/isFavorite'](source.id) ? 'pink' : ''"
          class="heart icon"
        />
      </button>
      <button
        :aria-label="source.labels.remove"
        :title="source.labels.remove"
        class="ui really tiny basic circular icon button"
        @click.stop="$emit('remove', index)"
      >
        <i class="x icon" />
      </button>
    </div>
  </div>
</template>
