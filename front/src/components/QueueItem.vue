<script setup functional lang="ts">
import type { QueueItemSource } from '~/types'

interface Props {
  source: QueueItemSource
  index: number
  itemClass: (index: number) => string
}

interface Emits {
  (e: 'play', index: number): void
  (e: 'remove', index: number): void
}

defineProps<Props>()
defineEmits<Emits>()
</script>

<template>
  <div
    :class="itemClass(index)"
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
        :title="source.track.title"
        :aria-label="source.labels.selectTrack"
      >
        <strong>{{ source.track.title }}</strong><br>
        <span>
          {{ source.track.artist.name }}
        </span>
      </button>
    </div>
    <div class="duration-cell">
      <template v-if="source.track.uploads.length > 0">
        {{ source.duration }}
      </template>
    </div>
    <div class="controls">
      <i
        :class="$store.getters['favorites/isFavorite'](source.track.id) ? 'pink' : 'grey'"
        class="heart icon ui favorite-icon"
        @click.stop="$store.dispatch('favorites/toggle', source.track.id)"
      />
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
