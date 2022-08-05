<script setup lang="ts">
import type { BackendError, ReviewState, Review } from '~/types'
import { ref, watchEffect } from 'vue'

import axios from 'axios'

import EditCard from '~/components/library/EditCard.vue'

interface Props {
  url: string
  filters?: object
  currentState?: ReviewState
}

const props = withDefaults(defineProps<Props>(), {
  filters: () => ({}),
  currentState: () => ({})
})

const errors = ref([] as string[])
const previousPage = ref()
const nextPage = ref()
const objects = ref([] as Review[])
const isLoading = ref(false)
const fetchData = async (url = props.url) => {
  isLoading.value = true
  const params = {
    ...props.filters,
    page_size: 5
  }

  try {
    const response = await axios.get(url, { params })
    previousPage.value = response.data.previous
    nextPage.value = response.data.next
    objects.value = response.data.results
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}

watchEffect(() => fetchData())
</script>

<template>
  <div class="wrapper">
    <h3 class="ui header">
      <slot />
    </h3>
    <slot
      v-if="!isLoading && objects.length === 0"
      name="empty-state"
    />
    <button
      v-if="nextPage || previousPage"
      :disabled="!previousPage"
      :class="['ui', {disabled: !previousPage}, 'circular', 'icon', 'basic', 'button']"
      @click="fetchData(previousPage)"
    >
      <i :class="['ui', 'angle left', 'icon']" />
    </button>
    <button
      v-if="nextPage || previousPage"
      :disabled="!nextPage"
      :class="['ui', {disabled: !nextPage}, 'circular', 'icon', 'basic', 'button']"
      @click="fetchData(nextPage)"
    >
      <i :class="['ui', 'angle right', 'icon']" />
    </button>
    <div class="ui hidden divider" />
    <div
      v-if="isLoading"
      class="ui inverted active dimmer"
    >
      <div class="ui loader" />
    </div>
    <edit-card
      v-for="obj in objects"
      :key="obj.uuid"
      :obj="obj"
      :current-state="currentState"
      @updated="fetchData(url)"
      @deleted="fetchData(url)"
    />
  </div>
</template>
