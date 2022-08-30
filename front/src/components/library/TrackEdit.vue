<script setup lang="ts">
import type { EditObject, EditObjectType } from '~/composables/moderation/useEditConfigs'
import type { Library } from '~/types'

import { ref } from 'vue'

import store from '~/store'
import axios from 'axios'

import useErrorHandler from '~/composables/useErrorHandler'
import EditForm from '~/components/library/EditForm.vue'

interface Props {
  objectType: EditObjectType
  object: EditObject
  libraries: Library[] | null
}

withDefaults(defineProps<Props>(), {
  libraries: null
})

const canEdit = store.state.auth.availablePermissions.library

const isLoadingLicenses = ref(false)
const licenses = ref([])
const fetchLicenses = async () => {
  isLoadingLicenses.value = true

  try {
    const response = await axios.get('licenses/')
    licenses.value = response.data.results
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoadingLicenses.value = false
}

fetchLicenses()
</script>

<template>
  <section class="ui vertical stripe segment">
    <div class="ui text container">
      <h2>
        <translate
          v-if="canEdit"
          translate-context="Content/*/Title"
        >
          Edit this track
        </translate>
        <translate
          key="2"
          translate-context="Content/*/Title"
        >
          Suggest an edit on this track
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
        v-else-if="!isLoadingLicenses"
        :object-type="objectType"
        :object="object"
        :can-edit="canEdit"
        :licenses="licenses"
      />
      <div
        v-else
        class="ui inverted active dimmer"
      >
        <div class="ui loader" />
      </div>
    </div>
  </section>
</template>
