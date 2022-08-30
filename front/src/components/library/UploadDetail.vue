<script setup lang="ts">
import { useRouter } from 'vue-router'
import { ref } from 'vue'

import axios from 'axios'

import useErrorHandler from '~/composables/useErrorHandler'

interface Props {
  id: number
}

const props = defineProps<Props>()

const router = useRouter()

const isLoading = ref(false)
const fetchData = async () => {
  isLoading.value = true

  try {
    const response = await axios.get(`uploads/${props.id}/`, {
      params: {
        refresh: 'true',
        include_channels: 'true'
      }
    })

    router.replace({
      name: 'library.tracks.detail',
      params: { id: response.data.track.id }
    })
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
      <div class="ui centered active inline loader" />
    </div>
  </main>
</template>
