<script setup lang="ts">
import type { Library } from '~/types'

import ArtistWidget from '~/components/audio/artist/Widget.vue'

interface Props {
  object: Library
  isOwner: boolean
}

defineProps<Props>()
</script>

<template>
  <section>
    <template v-if="$store.getters['ui/layoutVersion'] === 'small'">
      <rendered-description
        :content="object.description ? {html: object.description} : null"
        :update-url="`channels/${object.uuid}/`"
        :can-update="false"
      />
      <div class="ui hidden divider" />
    </template>
    <artist-widget
      :key="object.uploads_count"
      ref="artists"
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
    </artist-widget>
  </section>
</template>
