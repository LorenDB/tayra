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
        <translate
          v-if="canEdit"
          translate-context="Content/*/Title"
        >
          Edit this album
        </translate>
        <translate
          v-else
          translate-context="Content/*/Title"
        >
          Suggest an edit on this album
        </translate>
      </h2>
      <div
        v-if="!object.is_local"
        class="ui message"
      >
        <translate translate-context="Content/*/Message">
          This object is managed by another server, you cannot edit it.
        </translate>
      </div>
      <edit-form
        v-else
        :object-type="objectType"
        :object="object"
      />
    </div>
  </section>
</template>
