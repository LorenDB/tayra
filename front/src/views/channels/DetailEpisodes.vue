<script setup lang="ts">
import type { Channel } from '~/types'

import ChannelEntries from '~/components/audio/ChannelEntries.vue'

interface Props {
  object: Channel
}

defineProps<Props>()
</script>

<template>
  <section>
    <channel-entries
      :default-cover="object.artist?.cover"
      :is-podcast="object.artist?.content_category === 'podcast'"
      :limit="25"
      :filters="{channel: object.uuid, ordering: 'creation_date'}"
    />
  </section>
</template>
