<script setup lang="ts">
import type { EditObjectType } from '~/composables/moderation/useEditConfigs'
import type { Artist, Library } from '~/types'

import { useStore } from '~/store'

import EditForm from '~/components/library/EditForm.vue'

interface Props {
  objectType: EditObjectType
  object: Artist
  libraries: Library[]
}

defineProps<Props>()

const store = useStore()
const canEdit = store.state.auth.availablePermissions.library
</script>

<template>
  <section class="ui vertical stripe segment">
    <div class="ui text container">
      <h2>
        <span v-if="canEdit">
          {{ $t('components.library.ArtistEdit.header.edit') }}
        </span>
        <span v-else>
          {{ $t('components.library.ArtistEdit.header.suggest') }}
        </span>
      </h2>
      <div
        v-if="!object.is_local"
        class="ui message"
      >
        {{ $t('components.library.ArtistEdit.message.remote') }}
      </div>
      <edit-form
        v-else
        :object-type="objectType"
        :object="object"
      />
    </div>
  </section>
</template>
