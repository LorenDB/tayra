<script setup lang="ts">
import type { Library, LibraryFollow } from '~/types'

import { ref } from 'vue'

import axios from 'axios'

import ScanForm from './ScanForm.vue'
import LibraryCard from './Card.vue'

import useErrorHandler from '~/composables/useErrorHandler'

const existingFollows = ref()
const isLoading = ref(false)
const fetchData = async () => {
  isLoading.value = true

  try {
    const response = await axios.get('federation/follows/library/', { params: { page_size: 100, ordering: '-creation_date' } })
    existingFollows.value = response.data

    for (const follow of existingFollows.value.results) {
      follow.target.follow = follow
    }
  } catch (error) {
    useErrorHandler(error as Error)
  }

  isLoading.value = false
}

fetchData()

const getLibraryFromFollow = (follow: LibraryFollow) => {
  const { target } = follow
  target.follow = follow
  return target as Library
}

const scanResult = ref()
</script>

<template>
  <div class="ui vertical aligned stripe segment">
    <div
      v-if="isLoading"
      :class="['ui', {'active': isLoading}, 'inverted', 'dimmer']"
    >
      <div class="ui text loader">
        {{ $t('views.content.remote.Home.loading.remoteLibraries') }}
      </div>
    </div>
    <div
      v-else
      class="ui text container"
    >
      <h1 class="ui header">
        {{ $t('views.content.remote.Home.header.remoteLibraries') }}
      </h1>
      <p>
        {{ $t('views.content.remote.Home.description.remoteLibraries') }}
      </p>
      <scan-form @scanned="scanResult = $event" />
      <div class="ui hidden divider" />
      <div
        v-if="scanResult && scanResult.results.length > 0"
        class="ui two cards"
      >
        <library-card
          v-for="library in scanResult.results"
          :key="library.fid"
          :initial-library="library"
        />
      </div>
      <template v-if="existingFollows && existingFollows.count > 0">
        <h2>
          {{ $t('views.content.remote.Home.header.knownLibraries') }}
        </h2>
        <a
          href=""
          class="discrete link"
          @click.prevent="fetchData"
        >
          <i :class="['ui', 'circular', 'refresh', 'icon']" />
          {{ $t('views.content.remote.Home.button.refresh') }}
        </a>
        <div class="ui hidden divider" />
        <div class="ui two cards">
          <library-card
            v-for="follow in existingFollows.results"
            :key="follow.fid"
            :initial-library="getLibraryFromFollow(follow)"
            @deleted="fetchData"
            @followed="fetchData"
          />
        </div>
      </template>
    </div>
  </div>
</template>
