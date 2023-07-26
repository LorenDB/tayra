<script setup lang="ts">
import type { OrderingProps } from '~/composables/navigation/useOrdering'
import type { Album, BackendResponse } from '~/types'
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

import TagsSelector from '~/components/library/TagsSelector.vue'
import AlbumCard from '~/components/audio/album/Card.vue'
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

const result = ref<BackendResponse<Album>>()

const orderingOptions: [OrderingField, keyof typeof sharedLabels.filters][] = [
  ['creation_date', 'creation_date'],
  ['title', 'album_title'],
  ['release_date', 'release_date']
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
    content_category: 'music'
  }

  const measureLoading = logger.time('Fetching albums')
  try {
    const response = await axios.get('albums/', {
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
watch(() => store.state.moderation.lastUpdate, fetchData)
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
  searchPlaceholder: t('components.library.Albums.placeholder.search'),
  title: t('components.library.Albums.title')
}))

const paginateOptions = computed(() => sortedUniq([12, 25, 50, paginateBy.value].sort((a, b) => a - b)))
</script>

<template>
  <main v-title="labels.title">
    <section class="ui vertical stripe segment">
      <h2 class="ui header">
        {{ $t('components.library.Albums.header.browse') }}
      </h2>
      <form
        :class="['ui', {'loading': isLoading}, 'form']"
        @submit.prevent="search"
      >
        <div class="fields">
          <div class="field">
            <label for="albums-search">
              {{ $t('components.library.Albums.label.search') }}
            </label>
            <div class="ui action input">
              <input
                id="albums-search"
                v-model="query"
                type="text"
                name="search"
                :placeholder="labels.searchPlaceholder"
              >
              <button
                class="ui icon button"
                type="submit"
                :aria-label="t('components.library.Albums.button.search')"
              >
                <i class="search icon" />
              </button>
            </div>
          </div>
          <div class="field">
            <label for="tags-search">{{ $t('components.library.Albums.label.tags') }}</label>
            <tags-selector v-model="tags" />
          </div>
          <div class="field">
            <label for="album-ordering">{{ $t('components.library.Albums.ordering.label') }}</label>
            <select
              id="album-ordering"
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
            <label for="album-ordering-direction">{{ $t('components.library.Albums.ordering.direction.label') }}</label>
            <select
              id="album-ordering-direction"
              v-model="orderingDirection"
              class="ui dropdown"
            >
              <option value="+">
                {{ $t('components.library.Albums.ordering.direction.ascending') }}
              </option>
              <option value="-">
                {{ $t('components.library.Albums.ordering.direction.descending') }}
              </option>
            </select>
          </div>
          <div class="field">
            <label for="album-results">{{ $t('components.library.Albums.pagination.results') }}</label>
            <select
              id="album-results"
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
        v-if="result"
        transition-duration="0"
        item-selector=".column"
        percent-position="true"
        stagger="0"
        class=""
      >
        <div
          v-if="result.results.length > 0"
          class="ui app-cards cards"
        >
          <album-card
            v-for="album in result.results"
            :key="album.id"
            :album="album"
          />
        </div>
        <div
          v-else
          class="ui placeholder segment sixteen wide column"
          style="text-align: center; display: flex; align-items: center"
        >
          <div class="ui icon header">
            <i class="compact disc icon" />
            {{ $t('components.library.Albums.empty.noResults') }}
          </div>
          <router-link
            v-if="$store.state.auth.authenticated"
            :to="{name: 'content.index'}"
            class="ui success button labeled icon"
          >
            <i class="upload icon" />
            {{ $t('components.library.Albums.link.addMusic') }}
          </router-link>
        </div>
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
