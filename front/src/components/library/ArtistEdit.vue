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
        <translate
          v-if="canEdit"
        >
          Edit this artist
        </translate>
        <translate
          v-else
        >
          Suggest an edit on this artist
        </translate>
      </h2>
      <div
        v-if="!object.is_local"
        class="ui message"
      >
        This object is managed by another server, you cannot edit it.
      </div>
      <edit-form
        v-else
        :object-type="objectType"
        :object="object"
      />
    </div>
  </section>
</template>
