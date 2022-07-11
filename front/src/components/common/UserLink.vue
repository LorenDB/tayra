<script setup lang="ts">
import type { User } from '~/types'

import { hashCode, intToRGB } from '~/utils/color'
import { computed } from 'vue'

interface Props {
  user: User
  avatar?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  avatar: true
})

const userColor = computed(() => intToRGB(hashCode(props.user.username + props.user.id)))
const defaultAvatarStyle = computed(() => ({ backgroundColor: `#${userColor.value}` }))
</script>

<template>
  <span class="component-user-link">
    <template v-if="avatar">
      <img
        v-if="user.avatar && user.avatar.urls.medium_square_crop"
        v-lazy="$store.getters['instance/absoluteUrl'](user.avatar.urls.medium_square_crop)"
        class="ui tiny circular avatar"
        alt=""
      >
      <span
        v-else
        :style="defaultAvatarStyle"
        class="ui circular label"
      >{{ user.username[0] }}</span>
      &nbsp;
    </template>
    @{{ user.username }}
  </span>
</template>
