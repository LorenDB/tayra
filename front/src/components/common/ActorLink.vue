<script setup lang="ts">
import { toRefs } from '@vueuse/core'
import { computed } from 'vue'
import { truncate } from '~/utils/filters'
import { Actor } from '~/types'

interface Props {
  actor: Actor
  avatar?: boolean
  admin?: boolean
  displayName?: boolean
  truncateLength?: number
}

const { displayName, actor, truncateLength, admin, avatar } = toRefs(withDefaults(defineProps<Props>(), {
  avatar: true,
  admin: false,
  displayName: false,
  truncateLength: 30
}))

const repr = computed(() => {
  const name = displayName.value || actor.value.is_local
    ? actor.value.preferred_username
    : actor.value.full_username

  return truncate(name, truncateLength.value)
})

const url = computed(() => {
  if (admin.value) {
    return { name: 'manage.moderation.accounts.detail', params: { id: actor.value.full_username } }
  }

  if (actor.value.is_local) {
    return { name: 'profile.overview', params: { username: actor.value.preferred_username } }
  }

  return {
    name: 'profile.full.overview',
    params: {
      username: actor.value.preferred_username,
      domain: actor.value.domain
    }
  }
})
</script>

<template>
  <router-link
    :to="url"
    :title="actor.full_username"
  >
    <actor-avatar
      v-if="avatar"
      :actor="actor"
    />
    <span>&nbsp;</span>
    <slot>{{ repr }}</slot>
  </router-link>
</template>
