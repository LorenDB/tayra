<script setup lang="ts">
import type { OrderingProps } from '~/composables/navigation/useOrdering'
import type { Artist, BackendResponse } from '~/types'
import type { RouteRecordName } from 'vue-router'
import type { OrderingField } from '~/store/ui'

import { computed, ref, watch, onMounted } from 'vue'
import { useRouteQuery } from '@vueuse/router'
import { useI18n } from 'vue-i18n'
import { syncRef } from '@vueuse/core'
import { sortedUniq } from 'lodash-es'
import { useStore } from '~/store'

import axios from 'axios'
import $ from 'jquery'

import TagsSelector from '~/components/library/TagsSelector.vue'
import ArtistCard from '~/components/audio/artist/Card.vue'
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

const tags = useRouteQuery<string[]>('tag', [])

const q = useRouteQuery('query', '')
const query = ref(q.value)
syncRef(q, query, { direction: 'ltr' })

const result = ref<BackendResponse<Artist>>()
const excludeCompilation = ref(true)

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
    q: query.value,
    ordering: orderingString.value,
    playable: 'true',
    tag: tags.value,
    include_channels: 'true',
    content_category: 'music',
    has_albums: excludeCompilation.value
  }

  const measureLoading = logger.time('Fetching artists')
  try {
    const response = await axios.get('artists/', {
      params,
      paramsSerializer: {
        indexes: null
      }
    })

    result.value = response.data
  } catch (error) {
    useErrorHandler(error as Error)
    result.value = undefined
  } finally {
    measureLoading()
    isLoading.value = false
  }
}

const store = useStore()
watch([() => store.state.moderation.lastUpdate, excludeCompilation], fetchData)
watch([page, tags, q, () => props.scope], fetchData)
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
  searchPlaceholder: t('components.library.Artists.placeholder.search'),
  title: t('components.library.Artists.title')
}))

const paginateOptions = computed(() => sortedUniq([12, 30, 50, paginateBy.value].sort((a, b) => a - b)))
</script>

<template>
  <main v-title="labels.title">
    <section class="ui vertical stripe segment">
      <h2 class="ui header">
        {{ $t('components.library.Artists.header.browse') }}
      </h2>
      <form
        :class="['ui', {'loading': isLoading}, 'form']"
        @submit.prevent="search"
      >
        <div class="fields">
          <div class="field">
            <label for="artist-search">
              {{ $t('components.library.Artists.label.search') }}
            </label>
            <div class="ui action input">
              <input
                id="artist-search"
                v-model="query"
                type="text"
                name="search"
                :placeholder="labels.searchPlaceholder"
              >
              <button
                class="ui icon button"
                type="submit"
                :aria-label="t('components.library.Artists.button.search')"
              >
                <i class="search icon" />
              </button>
            </div>
          </div>
          <div class="field">
            <label for="tags-search">{{ $t('components.library.Artists.label.tags') }}</label>
            <tags-selector v-model="tags" />
          </div>
          <div class="field">
            <label for="artist-ordering">{{ $t('components.library.Artists.ordering.label') }}</label>
            <select
              id="artist-ordering"
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
            <label for="artist-ordering-direction">{{ $t('components.library.Artists.ordering.direction.label') }}</label>
            <select
              id="artist-ordering-direction"
              v-model="orderingDirection"
              class="ui dropdown"
            >
              <option value="+">
                {{ $t('components.library.Artists.ordering.direction.ascending') }}
              </option>
              <option value="-">
                {{ $t('components.library.Artists.ordering.direction.descending') }}
              </option>
            </select>
          </div>
          <div class="field">
            <label for="artist-results">{{ $t('components.library.Artists.pagination.results') }}</label>
            <select
              id="artist-results"
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
          <div class="field">
            <span id="excludeHeader">{{ $t('components.library.Artists.label.excludeCompilation') }}</span>
            <div
              id="excludeCompilation"
              class="ui toggle checkbox"
            >
              <input
                id="exclude-compilation"
                v-model="excludeCompilation"
                true-value="true"
                false-value="null"
                type="checkbox"
              >
              <label
                for="exclude-compilation"
                class="visually-hidden"
              >{{ $t('components.library.Artists.label.excludeCompilation') }}</label>
            </div>
          </div>
        </div>
      </form>
      <div class="ui hidden divider" />
      <div
        v-if="result && result.results.length > 0"
        class="ui five app-cards cards"
      >
        <div
          v-if="isLoading"
          class="ui inverted active dimmer"
        >
          <div class="ui loader" />
        </div>
        <artist-card
          v-for="artist in result.results"
          :key="artist.id"
          :artist="artist"
        />
      </div>
      <div
        v-else-if="!isLoading"
        class="ui placeholder segment sixteen wide column"
        style="text-align: center; display: flex; align-items: center"
      >
        <div class="ui icon header">
          <i class="compact disc icon" />
          {{ $t('components.library.Artists.empty.noResults') }}
        </div>
        <router-link
          v-if="$store.state.auth.authenticated"
          :to="{name: 'content.index'}"
          class="ui success button labeled icon"
        >
          <i class="upload icon" />
          {{ $t('components.library.Artists.button.upload') }}
        </router-link>
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
