<script setup lang="ts">
import type { EditObject, EditObjectType } from '~/composables/moderation/useEditConfigs'
import type { ReviewState } from '~/types'

import { computed, ref } from 'vue'

import axios from 'axios'

import EditCard from '~/components/library/EditCard.vue'

import useEditConfigs from '~/composables/moderation/useEditConfigs'
import useErrorHandler from '~/composables/useErrorHandler'

interface Props {
  object: EditObject
  objectType: EditObjectType
  editId: number
}

const props = defineProps<Props>()

const configs = useEditConfigs()
const config = computed(() => configs[props.objectType])

const currentState = computed(() => config.value.fields.reduce((state: ReviewState, field) => {
  state[field.id] = { value: field.getValue(props.object) }
  return state
}, {}))

const isLoading = ref(false)
const obj = ref()
const fetchData = async () => {
  isLoading.value = true

  try {
    const response = await axios.get(`mutations/${props.editId}/`)
    obj.value = response.data
  } catch (error) {
    useErrorHandler(error as Error)
  } finally {
    isLoading.value = false
  }
}

fetchData()
// TODO (wvffle): Check if we want to watch for editId change and refetch data
</script>

<template>
  <section :class="['ui', 'vertical', 'stripe', { loading: isLoading }, 'segment']">
    <div class="ui text container">
      <edit-card
        v-if="obj"
        :obj="obj"
        :current-state="currentState"
      />
    </div>
  </section>
</template>
