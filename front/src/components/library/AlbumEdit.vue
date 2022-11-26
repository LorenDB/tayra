<script setup lang="ts">
import type { EditObjectType } from '~/composables/moderation/useEditConfigs'
import type { Album, Library, Actor } from '~/types'

import { useStore } from '~/store'

import EditForm from '~/components/library/EditForm.vue'

interface Props {
  objectType: EditObjectType
  object: Album & { attributed_to: Actor }
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
          {{ $t('components.library.AlbumEdit.header.edit') }}
        </span>
        <span v-else>
          {{ $t('components.library.AlbumEdit.header.suggest') }}
        </span>
      </h2>
      <div
        v-if="!object.is_local"
        class="ui message"
      >
        {{ $t('components.library.AlbumEdit.message.remote') }}
      </div>
      <edit-form
        v-else
        :object-type="objectType"
        :object="object"
      />
    </div>
  </section>
</template>
