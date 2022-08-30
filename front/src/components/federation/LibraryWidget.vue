<script setup lang="ts">
import type { Library } from '~/types'

import { ref, reactive } from 'vue'

import axios from 'axios'

import LibraryCard from '~/views/content/remote/Card.vue'

import useErrorHandler from '~/composables/useErrorHandler'

interface Events {
  (e: 'loaded', libraries: Library[]): void
}

interface Props {
  url: string
}

const emit = defineEmits<Events>()
const props = defineProps<Props>()

const nextPage = ref()
const libraries = reactive([] as Library[])
const isLoading = ref(false)
const fetchData = async (url = props.url) => {
  isLoading.value = true

  try {
    const response = await axios.get(url, {
      params: {
        page_size: 6
      }
    })

    nextPage.value = response.data.next
    libraries.push(...response.data.results)
    emit('loaded', libraries)
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoading.value = false
}

fetchData()
</script>

<template>
  <div class="wrapper">
    <h3
      v-if="!!$slots.title"
      class="ui header"
    >
      <slot name="title" />
    </h3>
    <p
      v-if="!isLoading && libraries.length > 0"
      class="ui subtitle"
    >
      <slot />
    </p>
    <p
      v-if="!isLoading && libraries.length === 0"
      class="ui subtitle"
    >
      <translate translate-context="Content/Federation/Paragraph">
        No matching library.
      </translate>
    </p>
    <div class="ui hidden divider" />
    <div class="ui cards">
      <div
        v-if="isLoading"
        class="ui inverted active dimmer"
      >
        <div class="ui loader" />
      </div>
      <library-card
        v-for="library in libraries"
        :key="library.uuid"
        :display-scan="false"
        :display-follow="$store.state.auth.authenticated && library.actor.full_username != $store.state.auth.fullUsername"
        :initial-library="library"
        :display-copy-fid="true"
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
  </div>
</template>
