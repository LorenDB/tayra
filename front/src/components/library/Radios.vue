<script setup lang="ts">
import type { OrderingProps } from '~/composables/navigation/useOrdering'
import type { Radio, BackendResponse } from '~/types'
import type { RouteRecordName } from 'vue-router'
import type { OrderingField } from '~/store/ui'

import { computed, onMounted, ref, watch } from 'vue'
import { useRouteQuery } from '@vueuse/router'
import { useI18n } from 'vue-i18n'
import { syncRef } from '@vueuse/core'
import { sortedUniq } from 'lodash-es'
import { useStore } from '~/store'

import axios from 'axios'
import $ from 'jquery'

import Pagination from '~/components/vui/Pagination.vue'
import RadioCard from '~/components/radios/Card.vue'

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

const result = ref<BackendResponse<Radio>>()

const orderingOptions: [OrderingField, keyof typeof sharedLabels.filters][] = [
  ['creation_date', 'creation_date'],
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
    name__icontains: query.value,
    ordering: orderingString.value
  }

  logger.time('Fetching radios')
  try {
    const response = await axios.get('radios/radios/', {
      params
    })

    result.value = response.data
  } catch (error) {
    useErrorHandler(error as Error)
    result.value = undefined
  } finally {
    logger.timeEnd('Fetching radios')
    isLoading.value = false
  }
}

const store = useStore()
const isAuthenticated = computed(() => store.state.auth.authenticated)
const hasFavorites = computed(() => store.state.favorites.count > 0)

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
  searchPlaceholder: t('components.library.Radios.placeholder.search'),
  title: t('components.library.Radios.title')
}))

const paginateOptions = computed(() => sortedUniq([12, 25, 50, paginateBy.value].sort((a, b) => a - b)))
</script>

<template>
  <main v-title="labels.title">
    <section class="ui vertical stripe segment">
      <h2 class="ui header">
        {{ $t('components.library.Radios.header.browse') }}
      </h2>
      <div class="ui hidden divider" />
      <div class="ui row">
        <h3 class="ui header">
          {{ $t('components.library.Radios.header.instance') }}
        </h3>
        <div class="ui cards">
          <radio-card
            v-if="isAuthenticated"
            :type="'actor-content'"
            :object-id="$store.state.auth.fullUsername"
          />
          <radio-card
            v-if="isAuthenticated && hasFavorites"
            :type="'favorites'"
          />
          <radio-card
            v-if="scope === 'all'"
            :type="'random'"
          />
          <radio-card
            v-if="scope === 'me'"
            :type="'random_library'"
          />
          <radio-card :type="'recently-added'" />
          <radio-card
            v-if="$store.state.auth.authenticated && scope === 'all'"
            :type="'less-listened'"
          />
          <radio-card
            v-if="$store.state.auth.authenticated && scope === 'me'"
            :type="'less-listened_library'"
          />
        </div>
      </div>

      <div class="ui hidden divider" />
      <h3 class="ui header">
        {{ $t('components.library.Radios.header.user') }}
      </h3>
      <router-link
        v-if="isAuthenticated"
        class="ui success button"
        to="/library/radios/build"
      >
        {{ $t('components.library.Radios.button.create') }}
      </router-link>
      <div class="ui hidden divider" />
      <form
        :class="['ui', {'loading': isLoading}, 'form']"
        @submit.prevent="search"
      >
        <div class="fields">
          <div class="field">
            <label for="radios-search">{{ $t('components.library.Radios.label.search') }}</label>
            <div class="ui action input">
              <input
                id="radios-search"
                v-model="query"
                type="text"
                name="search"
                :placeholder="labels.searchPlaceholder"
              >
              <button
                class="ui icon button"
                type="submit"
                :aria-label="t('components.library.Radios.button.search')"
              >
                <i class="search icon" />
              </button>
            </div>
          </div>
          <div class="field">
            <label for="radios-ordering">{{ $t('components.library.Radios.ordering.label') }}</label>
            <select
              id="radios-ordering"
              v-model="ordering"
              class="ui dropdown"
            >
              <option
                v-for="(option, key) in orderingOptions"
                :key="key"
                :value="option[0]"
              >
                {{ sharedLabels.filters[option[1]] }}
              </option>
            </select>
          </div>
          <div class="field">
            <label for="radios-ordering-direction">{{ $t('components.library.Radios.ordering.direction.label') }}</label>
            <select
              id="radios-ordering-direction"
              v-model="orderingDirection"
              class="ui dropdown"
            >
              <option value="+">
                {{ $t('components.library.Radios.ordering.direction.ascending') }}
              </option>
              <option value="-">
                {{ $t('components.library.Radios.ordering.direction.descending') }}
              </option>
            </select>
          </div>
          <div class="field">
            <label for="radios-results">{{ $t('components.library.Radios.pagination.results') }}</label>
            <select
              id="radios-results"
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
      <div
        v-if="result && result.results.length === 0"
        class="ui placeholder segment"
      >
        <div class="ui icon header">
          <i class="feed icon" />
          {{ $t('components.library.Radios.empty.noResults') }}
        </div>
        <router-link
          v-if="$store.state.auth.authenticated"
          :to="{name: 'library.radios.build'}"
          class="ui success button labeled icon"
        >
          <i class="rss icon" />
          {{ $t('components.library.Radios.button.add') }}
        </router-link>
      </div>
      <div
        v-if="result && result.results.length > 0"
        class="ui cards"
      >
        <radio-card
          v-for="radio in result.results"
          :key="radio.id"
          type="custom"
          :custom-radio="radio"
        />
      </div>
      <div class="ui center aligned basic segment">
        <pagination
          v-if="result && result.count > paginateBy"
          v-model:current="page"
          :paginate-by="paginateBy"
          :total="result.count"
        />
      </div>
    </section>
  </main>
</template>
