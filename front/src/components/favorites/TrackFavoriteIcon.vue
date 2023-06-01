<script setup lang="ts">
import type { QueueTrack } from '~/composables/audio/queue'
import type { Track } from '~/types'

import { useI18n } from 'vue-i18n'
import { useStore } from '~/store'
import { computed } from 'vue'

interface Props {
  track?: QueueTrack | Track
  button?: boolean
  border?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  track: () => ({} as Track),
  button: false,
  border: false
})

const { t } = useI18n()
const store = useStore()

const isFavorite = computed(() => store.getters['favorites/isFavorite'](props.track.id))
const title = computed(() => isFavorite.value
  ? t('components.favorites.TrackFavoriteIcon.button.remove')
  : t('components.favorites.TrackFavoriteIcon.button.add')
)
</script>

<template>
  <button
    v-if="button"
    :class="['ui', 'pink', {'inverted': isFavorite}, {'favorited': isFavorite}, 'icon', 'labeled', 'button']"
    @click.stop="$store.dispatch('favorites/toggle', track.id)"
  >
    <i class="heart icon" />
    <span v-if="isFavorite">
      {{ $t('components.favorites.TrackFavoriteIcon.label.inFavorites') }}
    </span>
    <span v-else>
      {{ $t('components.favorites.TrackFavoriteIcon.button.add') }}
    </span>
  </button>
  <button
    v-else
    :class="['ui', 'favorite-icon', {'pink': isFavorite}, {'favorited': isFavorite}, 'basic', 'circular', 'icon', {'really': !border}, 'button']"
    :aria-label="title"
    :title="title"
    @click.stop="$store.dispatch('favorites/toggle', track.id)"
  >
    <i :class="['heart', {'pink': isFavorite}, 'basic', 'icon']" />
  </button>
</template>
