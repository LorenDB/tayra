<script setup lang="ts">
import type { Library } from '~/types'

import { computed } from 'vue'
import { useStore } from '~/store'

interface Props {
  library: Library
}

const props = defineProps<Props>()

const store = useStore()
const follow = computed(() => store.getters['libraries/follow'](props.library.uuid))
const isPending = computed(() => follow.value && follow.value.approved === null)
const isApproved = computed(() => follow.value && (follow.value?.approved === true || (isPending.value && props.library.privacy_level === 'everyone')))

const emit = defineEmits(['followed', 'unfollowed'])
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
    <translate
      v-if="isApproved"
      translate-context="Content/Library/Card.Button.Label/Verb"
    >
      Unfollow
    </translate>
    <translate
      v-else-if="isPending"
      translate-context="Content/Library/Card.Button.Label/Verb"
    >
      Cancel follow request
    </translate>
    <translate
      v-else
      translate-context="Content/Library/Card.Button.Label/Verb"
    >
      Follow
    </translate>
  </button>
</template>
