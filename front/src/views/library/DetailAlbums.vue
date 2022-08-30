<script setup lang="ts">
import type { Library } from '~/types'

import AlbumWidget from '~/components/audio/album/Widget.vue'

interface Props {
  object: Library
  isOwner: boolean
}

defineProps<Props>()
</script>

<template>
  <section>
    <album-widget
      :key="String(object.uploads_count)"
      :header="false"
      :search="true"
      :controls="false"
      :filters="{playable: true, ordering: '-creation_date', library: object.uuid}"
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
    </album-widget>
  </section>
</template>
