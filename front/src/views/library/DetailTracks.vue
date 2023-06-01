<script setup lang="ts">
import type { Library } from '~/types'

import TrackTable from '~/components/audio/track/Table.vue'

interface Props {
  object: Library
  isOwner: boolean
}

defineProps<Props>()
</script>

<template>
  <section>
    <track-table
      :key="object.uploads_count"
      :display-actions="false"
      :search="true"
      :filters="{playable: true, library: object.uuid, ordering: '-creation_date'}"
    >
      <template #empty-state>
        <empty-state>
          <p>
            <span
              v-if="isOwner"
            >
              {{ $t('views.library.DetailTracks.empty.upload') }}
            </span>
            <span
              v-else
            >
              {{ $t('views.library.DetailTracks.empty.follow') }}
            </span>
          </p>
        </empty-state>
      </template>
    </track-table>
  </section>
</template>
