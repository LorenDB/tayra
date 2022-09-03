<script setup lang="ts">
import type { OrderingProps } from '~/composables/navigation/useOrdering'
import type { Artist, BackendResponse } from '~/types'
import type { RouteRecordName } from 'vue-router'
import type { OrderingField } from '~/store/ui'

import { computed, ref, watch, onMounted } from 'vue'
import { useRouteQuery } from '@vueuse/router'
import { useGettext } from 'vue3-gettext'
import { syncRef } from '@vueuse/core'
import { sortedUniq } from 'lodash-es'
import { useStore } from '~/store'

import axios from 'axios'
import $ from 'jquery'
import qs from 'qs'

import TagsSelector from '~/components/library/TagsSelector.vue'
import RemoteSearchForm from '~/components/RemoteSearchForm.vue'
import SemanticModal from '~/components/semantic/Modal.vue'
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
const showSubscribeModal = ref(false)

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
    content_category: 'podcast'
  }

  logger.time('Fetching podcasts')
  try {
    const response = await axios.get('artists/', {
      params,
      paramsSerializer: function (params) {
        return qs.stringify(params, { indices: false })
      }
    })

    result.value = response.data
  } catch (error) {
    useErrorHandler(error as Error)
    result.value = undefined
  } finally {
    logger.timeEnd('Fetching podcasts')
    isLoading.value = false
  }
}

const store = useStore()
watch(() => store.state.moderation.lastUpdate, fetchData)
watch(page, fetchData)
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

const { $pgettext } = useGettext()
const labels = computed(() => ({
  searchPlaceholder: $pgettext('Content/Search/Input.Placeholder', 'Search…'),
  title: $pgettext('*/*/*/Noun', 'Podcasts')
}))

const paginateOptions = computed(() => sortedUniq([12, 30, 50, paginateBy.value].sort((a, b) => a - b)))
</script>

<template>
  <main v-title="labels.title">
    <section class="ui vertical stripe segment">
      <h2 class="ui header">
        <translate translate-context="Content/Podcasts/Title">
          Browsing podcasts
        </translate>
      </h2>
      <form
        :class="['ui', {'loading': isLoading}, 'form']"
        @submit.prevent="search"
      >
        <div class="fields">
          <div class="field">
            <label for="artist-search">
              <translate translate-context="Content/Search/Input.Label/Noun">Podcast title</translate>
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
                :aria-label="$pgettext('Content/Search/Input.Label/Noun', 'Search')"
              >
                <i class="search icon" />
              </button>
            </div>
          </div>
          <div class="field">
            <label for="tags-search"><translate translate-context="*/*/*/Noun">Tags</translate></label>
            <tags-selector v-model="tags" />
          </div>
          <div class="field">
            <label for="artist-ordering"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering</translate></label>
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
            <label for="artist-ordering-direction"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering direction</translate></label>
            <select
              id="artist-ordering-direction"
              v-model="orderingDirection"
              class="ui dropdown"
            >
              <option value="+">
                <translate translate-context="Content/Search/Dropdown">
                  Ascending
                </translate>
              </option>
              <option value="-">
                <translate translate-context="Content/Search/Dropdown">
                  Descending
                </translate>
              </option>
            </select>
          </div>
          <div class="field">
            <label for="artist-results"><translate translate-context="Content/Search/Dropdown.Label/Noun">Results per page</translate></label>
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
          <i class="podcast icon" />
          <translate translate-context="Content/Artists/Placeholder">
            No results matching your query
          </translate>
        </div>
        <router-link
          v-if="$store.state.auth.authenticated"
          :to="{name: 'content.index'}"
          class="ui success button labeled icon"
        >
          <i class="upload icon" />
          <translate translate-context="Content/*/Verb">
            Create a Channel
          </translate>
        </router-link>
        <h1
          v-if="$store.state.auth.authenticated"
          class="ui with-actions header"
        >
          <div class="actions">
            <a @click.stop.prevent="showSubscribeModal = true">
              <i class="plus icon" />
              <translate translate-context="Content/Profile/Button">Subscribe to feed</translate>
            </a>
          </div>
        </h1>
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
    <semantic-modal
      v-model:show="showSubscribeModal"
      class="tiny"
      :fullscreen="false"
    >
      <h2 class="header">
        <translate translate-context="*/*/*/Noun">
          Subscription
        </translate>
      </h2>
      <div
        ref="modalContent"
        class="scrolling content"
      >
        <remote-search-form
          type="both"
          :show-submit="false"
          :standalone="false"
          :redirect="true"
          @subscribed="showSubscribeModal = false; fetchData()"
        />
      </div>
      <div class="actions">
        <button class="ui basic deny button">
          <translate translate-context="*/*/Button.Label/Verb">
            Cancel
          </translate>
        </button>
        <button
          form="remote-search"
          type="submit"
          class="ui primary button"
        >
          <i class="bookmark icon" />
          <translate translate-context="*/*/*/Verb">
            Subscribe
          </translate>
        </button>
      </div>
    </semantic-modal>
  </main>
</template>
