<script setup lang="ts">
import type { Library } from '~/types'
import { useRouter } from 'vue-router'
import { ref } from 'vue'

import axios from 'axios'

import LibraryForm from './Form.vue'
import LibraryCard from './Card.vue'
import Quota from './Quota.vue'

import useErrorHandler from '~/composables/useErrorHandler'

const router = useRouter()

const libraries = ref([] as Library[])
const isLoading = ref(false)
const hiddenForm = ref(true)
const fetchData = async () => {
  isLoading.value = true

  try {
    const response = await axios.get('libraries/', { params: { scope: 'me' } })
    libraries.value = response.data.results
    if (libraries.value.length === 0) {
      hiddenForm.value = false
    }
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoading.value = false
}

fetchData()

const libraryCreated = (library: Library) => {
  router.push({ name: 'library.detail', params: { id: library.uuid } })
}
</script>

<template>
  <section class="ui vertical aligned stripe segment">
    <div
      v-if="isLoading"
      :class="['ui', {'active': isLoading}, 'inverted', 'dimmer']"
    >
      <div class="ui text loader">
        <translate translate-context="Content/Library/Paragraph">
          Loading Libraries…
        </translate>
      </div>
    </div>
    <div
      v-else
      class="ui text container"
    >
      <h1 class="ui header">
        <translate translate-context="Content/Library/Title">
          My libraries
        </translate>
      </h1>

      <p v-if="libraries.length == 0">
        <translate translate-context="Content/Library/Paragraph">
          Looks like you don't have a library, it's time to create one.
        </translate>
      </p>
      <a
        :aria-expanded="!hiddenForm"
        href=""
        @click.prevent="hiddenForm = !hiddenForm"
      >
        <i
          v-if="hiddenForm"
          class="plus icon"
        />
        <i
          v-else
          class="minus icon"
        />
        <translate translate-context="Content/Library/Link/Verb">Create a new library</translate>
      </a>
      <library-form
        v-if="!hiddenForm"
        :library="null"
        @created="libraryCreated"
      />
      <div class="ui hidden divider" />
      <quota />
      <div class="ui hidden divider" />
      <div
        v-if="libraries.length > 0"
        class="ui two column grid"
      >
        <div
          v-for="library in libraries"
          :key="library.uuid"
          class="column"
        >
          <library-card :library="library" />
        </div>
      </div>
    </div>
  </section>
</template>
