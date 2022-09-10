<script setup lang="ts">
import type { OrderingProps } from '~/composables/navigation/useOrdering'
import type { Playlist, BackendResponse } from '~/types'
import type { RouteRecordName } from 'vue-router'
import type { OrderingField } from '~/store/ui'

import { computed, onMounted, ref, watch } from 'vue'
import { useRouteQuery } from '@vueuse/router'
import { useI18n } from 'vue-i18n'
import { syncRef } from '@vueuse/core'
import { sortedUniq } from 'lodash-es'

import axios from 'axios'
import $ from 'jquery'

import PlaylistCardList from '~/components/playlists/CardList.vue'
import Pagination from '~/components/vui/Pagination.vue'

import useSharedLabels from '~/composables/locale/useSharedLabels'
import useOrdering from '~/composables/navigation/useOrdering'
import useErrorHandler from '~/composables/useErrorHandler'
import usePage from '~/composables/navigation/usePage'
import useLogger from '~/composables/useLogger'

interface Props extends OrderingProps {
  scope?: 'me' | 'all'

  // TODO(wvffle): Remove after https://github.com/vuejs/core/pull/4512 is merged
  orderingConfigName?: RouteRecordName
}

const props = withDefaults(defineProps<Props>(), {
  scope: 'all',
  orderingConfigName: undefined
})

const page = usePage()

const q = useRouteQuery('query', '')
const query = ref(q.value)
syncRef(q, query, { direction: 'ltr' })

const result = ref<BackendResponse<Playlist>>()

const orderingOptions: [OrderingField, keyof typeof sharedLabels.filters][] = [
  ['creation_date', 'creation_date'],
  ['modification_date', 'modification_date'],
  ['name', 'name']
]

const logger = useLogger()
const sharedLabels = useSharedLabels()

const { onOrderingUpdate, orderingString, paginateBy, ordering, orderingDirection } = useOrdering(props)

const isLoading = ref(false)
const fetchData = async () => {
  isLoading.value = true
  const params = {
    scope: props.scope,
    page: page.value,
    page_size: paginateBy.value,
    q: query.value,
    ordering: orderingString.value,
    playable: true
  }

  logger.time('Fetching albums')
  try {
    const response = await axios.get('playlists/', {
      params
    })

    result.value = response.data
  } catch (error) {
    useErrorHandler(error as Error)
    result.value = undefined
  } finally {
    logger.timeEnd('Fetching albums')
    isLoading.value = false
  }
}
watch([page, q, () => props.scope], fetchData)
fetchData()

const search = () => {
  page.value = 1
  q.value = query.value
}

onOrderingUpdate(() => {
  page.value = 1
  fetchData()
})

onMounted(() => $('.ui.dropdown').dropdown())

const { t } = useI18n()
const labels = computed(() => ({
  playlists: t('Playlists'),
  searchPlaceholder: t('Enter playlist name…')
}))

const paginateOptions = computed(() => sortedUniq([12, 25, 50, paginateBy.value].sort((a, b) => a - b)))
</script>

<template>
  <main v-title="labels.playlists">
    <section class="ui vertical stripe segment">
      <h2 class="ui header">
        Browsing playlists
      </h2>
      <template v-if="$store.state.auth.authenticated">
        <button
          class="ui success button"
          @click="$store.commit('playlists/showModal', true)"
        >
          Manage your playlists
        </button>
        <div class="ui hidden divider" />
      </template>
      <form
        :class="['ui', {'loading': isLoading}, 'form']"
        @submit.prevent="search"
      >
        <div class="fields">
          <div class="field">
            <label for="playlists-search">Search</label>
            <div class="ui action input">
              <input
                id="playlists-search"
                v-model="query"
                stype="text"
                name="search"
                :placeholder="labels.searchPlaceholder"
              >
              <button
                class="ui icon button"
                type="submit"
                :aria-label="t('Search')"
              >
                <i class="search icon" />
              </button>
            </div>
          </div>
          <div class="field">
            <label for="playlists-ordering">Ordering</label>
            <select
              id="playlists-ordering"
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
            <label for="playlists-ordering-direction">Order</label>
            <select
              id="playlists-ordering-direction"
              v-model="orderingDirection"
              class="ui dropdown"
            >
              <option value="+">
                Ascending
              </option>
              <option value="-">
                Descending
              </option>
            </select>
          </div>
          <div class="field">
            <label for="playlists-results">Results per page</label>
            <select
              id="playlists-results"
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
      </form>
      <div class="ui hidden divider" />
      <playlist-card-list
        v-if="result && result.results.length > 0"
        :playlists="result.results"
      />
      <div
        v-else-if="result && result.results.length === 0"
        class="ui placeholder segment sixteen wide column"
        style="text-align: center; display: flex; align-items: center"
      >
        <div class="ui icon header">
          <i class="list icon" />
          No results matching your query
        </div>
        <button
          v-if="$store.state.auth.authenticated"
          class="ui success button labeled icon"
          @click="$store.commit('playlists/chooseTrack', null)"
        >
          <i class="list icon" />
          Create a playlist
        </button>
      </div>
      <div class="ui center aligned basic segment">
        <pagination
          v-if="result && result.results.length > 0"
          v-model:current="page"
          :paginate-by="paginateBy"
          :total="result.count"
        />
      </div>
    </section>
  </main>
</template>
