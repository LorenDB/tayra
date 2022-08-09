<script setup lang="ts">
import type { RouteWithPreferences, OrderingField } from '~/store/ui'
import type { OrderingProps } from '~/composables/useOrdering'

import { onBeforeRouteUpdate, useRouter } from 'vue-router'
import { computed, ref, watch, onMounted } from 'vue'
import { useGettext } from 'vue3-gettext'
import { useStore } from '~/store'

import axios from 'axios'
import $ from 'jquery'

import Pagination from '~/components/vui/Pagination.vue'
import RadioCard from '~/components/radios/Card.vue'

import useSharedLabels from '~/composables/locale/useSharedLabels'
import useErrorHandler from '~/composables/useErrorHandler'
import useOrdering from '~/composables/useOrdering'
import useLogger from '~/composables/useLogger'

interface Props extends OrderingProps {
  defaultPage?: number

  defaultQuery?: string
  scope?: string

  // TODO(wvffle): Remove after https://github.com/vuejs/core/pull/4512 is merged
  orderingConfigName: RouteWithPreferences | null
}

const props = withDefaults(defineProps<Props>(), {
  defaultPage: 1,
  defaultQuery: '',
  scope: 'all'
})

// TODO (wvffle): Make sure everything is it's own type
const page = ref(+props.defaultPage)
type ResponseType = { count: number, results: any[] }
const result = ref<null | ResponseType>(null)
const query = ref(props.defaultQuery)

const orderingOptions: [OrderingField, keyof typeof sharedLabels.filters][] = [
  ['creation_date', 'creation_date'],
  ['name', 'name']
]

const logger = useLogger()
const sharedLabels = useSharedLabels()

const { onOrderingUpdate, orderingString, paginateBy, ordering, orderingDirection } = useOrdering(props.orderingConfigName)

const router = useRouter()
const updateQueryString = () => router.replace({
  query: {
    query: query.value,
    page: page.value,
    paginateBy: paginateBy.value,
    ordering: orderingString.value
  }
})

watch(page, updateQueryString)
onOrderingUpdate(updateQueryString)

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
    result.value = null
  } finally {
    logger.timeEnd('Fetching radios')
    isLoading.value = false
  }
}

const store = useStore()
const isAuthenticated = computed(() => store.state.auth.authenticated)
const hasFavorites = computed(() => store.state.favorites.count > 0)

onBeforeRouteUpdate(fetchData)
fetchData()

onMounted(() => $('.ui.dropdown').dropdown())

const { $pgettext } = useGettext()
const labels = computed(() => ({
  searchPlaceholder: $pgettext('Content/Search/Input.Placeholder', 'Enter a radio name…'),
  title: $pgettext('*/*/*', 'Radios')
}))
</script>

<template>
  <main v-title="labels.title">
    <section class="ui vertical stripe segment">
      <h2 class="ui header">
        <translate translate-context="Content/Radio/Title">
          Browsing radios
        </translate>
      </h2>
      <div class="ui hidden divider" />
      <div class="ui row">
        <h3 class="ui header">
          <translate translate-context="Content/Radio/Title">
            Instance radios
          </translate>
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
          <radio-card :type="'random'" />
          <radio-card :type="'recently-added'" />
          <radio-card
            v-if="$store.state.auth.authenticated"
            :type="'less-listened'"
          />
        </div>
      </div>

      <div class="ui hidden divider" />
      <h3 class="ui header">
        <translate translate-context="Content/Radio/Title">
          User radios
        </translate>
      </h3>
      <router-link
        v-if="isAuthenticated"
        class="ui success button"
        to="/library/radios/build"
      >
        <translate translate-context="Content/Radio/Button.Label/Verb">
          Create your own radio
        </translate>
      </router-link>
      <div class="ui hidden divider" />
      <form
        :class="['ui', {'loading': isLoading}, 'form']"
        @submit.prevent="page = props.defaultPage"
      >
        <div class="fields">
          <div class="field">
            <label for="radios-search"><translate translate-context="Content/Search/Input.Label/Noun">Search</translate></label>
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
                :aria-label="$pgettext('Content/Search/Input.Label/Noun', 'Search')"
              >
                <i class="search icon" />
              </button>
            </div>
          </div>
          <div class="field">
            <label for="radios-ordering"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering</translate></label>
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
            <label for="radios-ordering-direction"><translate translate-context="Content/Search/Dropdown.Label/Noun">Order</translate></label>
            <select
              id="radios-ordering-direction"
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
            <label for="radios-results"><translate translate-context="Content/Search/Dropdown.Label/Noun">Results per page</translate></label>
            <select
              id="radios-results"
              v-model="paginateBy"
              class="ui dropdown"
            >
              <option :value="12">
                12
              </option>
              <option :value="25">
                25
              </option>
              <option :value="50">
                50
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
          <translate translate-context="Content/Radios/Placeholder">
            No results matching your query
          </translate>
        </div>
        <router-link
          v-if="$store.state.auth.authenticated"
          :to="{name: 'library.radios.build'}"
          class="ui success button labeled icon"
        >
          <i class="rss icon" />
          <translate translate-context="Content/*/Verb">
            Create a radio
          </translate>
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
