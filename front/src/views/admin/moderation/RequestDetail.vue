<script setup lang="ts">
import { ref } from 'vue'

import axios from 'axios'

import UserRequestCard from '~/components/manage/moderation/UserRequestCard.vue'

import useErrorHandler from '~/composables/useErrorHandler'

interface Props {
  id: number
}

const props = defineProps<Props>()

const isLoading = ref(false)
const object = ref()
const fetchData = async () => {
  isLoading.value = true

  try {
    const response = await axios.get(`manage/moderation/requests/${props.id}/`)
    object.value = response.data
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoading.value = false
}

fetchData()
</script>

<template>
  <main>
    <div
      v-if="isLoading"
      class="ui vertical segment"
    >
      <div :class="['ui', 'centered', 'active', 'inline', 'loader']" />
    </div>
    <template v-if="object">
      <div class="ui vertical stripe segment">
        <user-request-card :init-obj="object" />
      </div>
    </template>
  </main>
</template>
