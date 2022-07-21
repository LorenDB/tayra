<script setup lang="ts">
import type { BackendError, Channel } from '~/types'

import { clone } from 'lodash-es'
import { ref, reactive } from 'vue'

import axios from 'axios'
import ChannelCard from '~/components/audio/ChannelCard.vue'

interface Props {
  filters: object
  limit?: number
}

const emit = defineEmits(['fetched'])
const props = withDefaults(defineProps<Props>(), {
  limit: 5
})

const channels = reactive([] as Channel[])
const errors = ref([] as string[])
const nextPage = ref()
const count = ref(0)

const isLoading = ref(false)
const fetchData = async (url = 'channels/') => {
  isLoading.value = true

  const params = {
    ...clone(props.filters),
    page_size: props.limit,
    include_channels: true
  }

  try {
    const response = await axios.get(url, { params })
    nextPage.value = response.data.next
    count.value = response.data.count
    channels.push(...response.data.results)
    emit('fetched', response.data)
  } catch (error) {
    errors.value = (error as BackendError).backendErrors
  }

  isLoading.value = false
}

fetchData()
</script>

<template>
  <div>
    <slot />
    <div class="ui hidden divider" />
    <div class="ui app-cards cards">
      <div
        v-if="isLoading"
        class="ui inverted active dimmer"
      >
        <div class="ui loader" />
      </div>
      <channel-card
        v-for="object in channels"
        :key="object.uuid"
        :object="object"
      />
    </div>
    <template v-if="nextPage">
      <div class="ui hidden divider" />
      <button
        v-if="nextPage"
        :class="['ui', 'basic', 'button']"
        @click="fetchData(nextPage)"
      >
        <translate translate-context="*/*/Button,Label">
          Show more
        </translate>
      </button>
    </template>
    <template v-if="!isLoading && channels.length === 0">
      <empty-state
        :refresh="true"
        @refresh="fetchData('channels/')"
      />
    </template>
  </div>
</template>
