<script setup lang="ts">
import type { Album, Library } from '~/types'

import { useStore } from '~/store'

import EditForm from '~/components/library/EditForm.vue'

interface Props {
  objectType: string
  object: Album
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
        :can-edit="canEdit"
      />
    </div>
  </section>
</template>
