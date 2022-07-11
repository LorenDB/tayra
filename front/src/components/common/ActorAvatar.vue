<script setup lang="ts">
import type { Actor } from '~/types'

import { hashCode, intToRGB } from '~/utils/color'
import { computed } from 'vue'

interface Props {
  actor: Actor
}

const props = defineProps<Props>()

const actorColor = computed(() => intToRGB(hashCode(props.actor.full_username)))
const defaultAvatarStyle = computed(() => ({ backgroundColor: `#${actorColor.value}` }))
</script>

<template>
  <img
    v-if="actor.icon && actor.icon.urls.original"
    alt=""
    :src="actor.icon.urls.medium_square_crop"
    class="ui avatar circular image"
  >
  <span
    v-else
    :style="defaultAvatarStyle"
    class="ui avatar circular label"
  >{{ actor.preferred_username[0] }}</span>
</template>
