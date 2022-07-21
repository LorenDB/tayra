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
            <translate
              v-if="isOwner"
              translate-context="*/*/*"
            >
              This library is empty, you should upload something in it!
            </translate>
            <translate
              v-else
              translate-context="*/*/*"
            >
              You may need to follow this library to see its content.
            </translate>
          </p>
        </empty-state>
      </template>
    </track-table>
  </section>
</template>
