<script setup lang="ts">
import type { Library } from '~/types'

import { computed } from 'vue'
import { useStore } from '~/store'

interface Events {
  (e: 'unfollowed'): void
  (e: 'followed'): void
}

interface Props {
  library: Library
}

const emit = defineEmits<Events>()
const props = defineProps<Props>()

const store = useStore()
const follow = computed(() => store.getters['libraries/follow'](props.library.uuid))
const isPending = computed(() => follow.value && follow.value.approved === null)
const isApproved = computed(() => follow.value && (follow.value?.approved === true || (isPending.value && props.library.privacy_level === 'everyone')))

const toggle = () => {
  if (isPending.value || isApproved.value) {
    emit('unfollowed')
  } else {
    emit('followed')
  }

  return store.dispatch('libraries/toggle', props.library.uuid)
}
</script>

<template>
  <button
    :class="['ui', 'pink', {'inverted': isApproved || isPending}, {'favorited': isApproved}, 'icon', 'labeled', 'button']"
    @click.stop="toggle"
  >
    <i class="heart icon" />
    <span v-if="isApproved">
      {{ $t('components.audio.LibraryFollowButton.button.unfollow') }}
    </span>
    <span v-else-if="isPending">
      {{ $t('components.audio.LibraryFollowButton.button.cancel') }}
    </span>
    <span v-else>
      {{ $t('components.audio.LibraryFollowButton.button.follow') }}
    </span>
  </button>
</template>
