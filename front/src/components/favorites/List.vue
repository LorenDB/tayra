<script setup lang="ts">
import type { OrderingProps } from '~/composables/navigation/useOrdering'
import type { RouteRecordName } from 'vue-router'
import type { OrderingField } from '~/store/ui'
import type { Track } from '~/types'

import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { sortedUniq } from 'lodash-es'
import { useStore } from '~/store'

import axios from 'axios'
import $ from 'jquery'

import TrackTable from '~/components/audio/track/Table.vue'
import RadioButton from '~/components/radios/Button.vue'
import Pagination from '~/components/vui/Pagination.vue'

import useSharedLabels from '~/composables/locale/useSharedLabels'
import useOrdering from '~/composables/navigation/useOrdering'
import useErrorHandler from '~/composables/useErrorHandler'
import usePage from '~/composables/navigation/usePage'
import useLogger from '~/composables/useLogger'

interface Props extends OrderingProps {
  // TODO(wvffle): Remove after https://github.com/vuejs/core/pull/4512 is merged
  orderingConfigName?: RouteRecordName
}

const props = withDefaults(defineProps<Props>(), {
  defaultPage: 1,
  orderingConfigName: undefined
})

const store = useStore()

const page = usePage()

const orderingOptions: [OrderingField, keyof typeof sharedLabels.filters][] = [
  ['creation_date', 'creation_date'],
  ['title', 'track_title'],
  ['album__title', 'album_title'],
  ['artist__name', 'artist_name']
]

const logger = useLogger()
const sharedLabels = useSharedLabels()

const { onOrderingUpdate, orderingString, paginateBy, ordering, orderingDirection } = useOrdering(props)

const results = reactive<Track[]>([])
const nextLink = ref()
const previousLink = ref()
const count = ref(0)

const isLoading = ref(false)
const fetchFavorites = async () => {
  isLoading.value = true

  const params = {
    favorites: 'true',
    page: page.value,
    page_size: paginateBy.value,
    ordering: orderingString.value
  }

  try {
    const stop = logger.time('Loading user favorites')
    const response = await axios.get('tracks/', { params })

    results.length = 0
    results.push(...response.data.results)

    for (const track of results) {
      store.commit('favorites/track', { id: track.id, value: true })
    }

    count.value = response.data.count
    nextLink.value = response.data.next
    previousLink.value = response.data.previous
  } catch (error) {
    useErrorHandler(error as Error)
  } finally {
    stop()
    isLoading.value = false
  }
}

watch(page, fetchFavorites)
fetchFavorites()

onOrderingUpdate(() => {
  page.value = 1
  fetchFavorites()
})

onMounted(() => $('.ui.dropdown').dropdown())

const { t } = useI18n()
const labels = computed(() => ({
  title: t('components.favorites.List.title')
}))

const paginateOptions = computed(() => sortedUniq([12, 25, 50, paginateBy.value].sort((a, b) => a - b)))
</script>

<template>
  <main
    v-title="labels.title"
    class="main pusher"
  >
    <section class="ui vertical center aligned stripe segment">
      <div :class="['ui', { 'active': isLoading }, 'inverted', 'dimmer']">
        <div class="ui text loader">
          {{ $t('components.favorites.List.loader.loading') }}
        </div>
      </div>
      <h2
        v-if="results"
        class="ui center aligned icon header"
      >
        <i class="circular inverted heart pink icon" />
        {{ $t('components.favorites.List.header.favorites', $store.state.favorites.count) }}
      </h2>
      <radio-button
        v-if="$store.state.favorites.count > 0"
        type="favorites"
      />
    </section>
    <section
      v-if="$store.state.favorites.count > 0"
      class="ui vertical stripe segment"
    >
      <div :class="['ui', { 'loading': isLoading }, 'form']">
        <div class="fields">
          <div class="field">
            <label for="favorites-ordering">
              {{ $t('components.favorites.List.ordering.label') }}
            </label>
            <select
              id="favorites-ordering"
              v-model="ordering"
              class="ui dropdown"
            >
              <option
                v-for="option in orderingOptions"
                :key="option[0]"
                :value="option[0]"
              >
                {{ sharedLabels.filters[option[1]] }}
              </option>
            </select>
          </div>
          <div class="field">
            <label for="favorites-ordering-direction">
              {{ $t('components.favorites.List.ordering.direction.label') }}
            </label>
            <select
              id="favorites-ordering-direction"
              v-model="orderingDirection"
              class="ui dropdown"
            >
              <option value="+">
                {{ $t('components.favorites.List.ordering.direction.ascending') }}
              </option>
              <option value="-">
                {{ $t('components.favorites.List.ordering.direction.descending') }}
              </option>
            </select>
          </div>
          <div class="field">
            <label for="favorites-results">
              {{ $t('components.favorites.List.pagination.results') }}
            </label>
            <select
              id="favorites-results"
              v-model="paginateBy"
              class="ui dropdown"
            >
              <option
                v-for="opt in paginateOptions"
                :key="opt"
                :value="opt"
              >
                {{ opt }}
              </option>
            </select>
          </div>
        </div>
      </div>
      <track-table
        v-if="results"
        :show-artist="true"
        :show-album="true"
        :tracks="results"
      />
      <div class="ui center aligned basic segment">
        <pagination
          v-if="results && count > paginateBy"
          v-model:current="page"
          :paginate-by="paginateBy"
          :total="count"
        />
      </div>
    </section>
    <div
      v-else
      class="ui placeholder segment"
    >
      <div class="ui icon header">
        <i class="broken heart icon" />
        {{ $t('components.favorites.List.empty.noFavorites') }}
      </div>
      <router-link
        :to="'/library'"
        class="ui success labeled icon button"
      >
        <i class="headphones icon" />
        {{ $t('components.favorites.List.link.library') }}
      </router-link>
    </div>
  </main>
</template>
