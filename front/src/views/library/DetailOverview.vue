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
            <span
              v-if="isOwner"
            >
              {{ $t('views.library.DetailOverview.empty.upload') }}
            </span>
            <span
              v-else
            >
              {{ $t('views.library.DetailOverview.empty.follow') }}
            </span>
          </p>
        </empty-state>
      </template>
    </artist-widget>
  </section>
</template>
