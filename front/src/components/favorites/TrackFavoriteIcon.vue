<script setup lang="ts">
import type { Track } from '~/types'

import { useGettext } from 'vue3-gettext'
import { useStore } from '~/store'
import { computed } from 'vue'

interface Props {
  track?: Track
  button?: boolean
  border?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  track: () => ({} as Track),
  button: false,
  border: false
})

const { $pgettext } = useGettext()
const store = useStore()

const isFavorite = computed(() => store.getters['favorites/isFavorite'](props.track.id))
const title = computed(() => isFavorite.value
  ? $pgettext('Content/Track/Icon.Tooltip/Verb', 'Remove from favorites')
  : $pgettext('Content/Track/*/Verb', 'Add to favorites')
)
</script>

<template>
  <button
    v-if="button"
    :class="['ui', 'pink', {'inverted': isFavorite}, {'favorited': isFavorite}, 'icon', 'labeled', 'button']"
    @click.stop="$store.dispatch('favorites/toggle', track.id)"
  >
    <i class="heart icon" />
    <translate
      v-if="isFavorite"
      translate-context="Content/Track/Button.Message"
    >
      In favorites
    </translate>
    <translate
      v-else
      translate-context="Content/Track/*/Verb"
    >
      Add to favorites
    </translate>
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
