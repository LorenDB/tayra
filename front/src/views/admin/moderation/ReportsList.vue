<script setup lang="ts">
import type { RouteWithPreferences, OrderingField } from '~/store/ui'
import type { SmartSearchProps } from '~/composables/useSmartSearch'
import type { OrderingProps } from '~/composables/useOrdering'

import { computed, ref, watch } from 'vue'
import { useGettext } from 'vue3-gettext'
import { useStore } from '~/store'

import axios from 'axios'

import ReportCategoryDropdown from '~/components/moderation/ReportCategoryDropdown.vue'
import ReportCard from '~/components/manage/moderation/ReportCard.vue'
import Pagination from '~/components/vui/Pagination.vue'

import useSharedLabels from '~/composables/locale/useSharedLabels'
import useErrorHandler from '~/composables/useErrorHandler'
import useSmartSearch from '~/composables/useSmartSearch'
import useOrdering from '~/composables/useOrdering'

interface Props extends SmartSearchProps, OrderingProps {
  mode?: 'card'

  // TODO(wvffle): Remove after https://github.com/vuejs/core/pull/4512 is merged
  orderingConfigName: RouteWithPreferences | null
  defaultQuery?: string
  updateUrl?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  defaultQuery: '',
  updateUrl: false,
  mode: 'card'
})

const search = ref()

// TODO (wvffle): Make sure everything is it's own type
const page = ref(1)
type ResponseType = { count: number, results: any[] }
const result = ref<null | ResponseType>(null)

const { onSearch, query, addSearchToken, getTokenValue } = useSmartSearch(props.defaultQuery, props.updateUrl)
const { onOrderingUpdate, orderingString, paginateBy, ordering, orderingDirection } = useOrdering(props.orderingConfigName)

const orderingOptions: [OrderingField, keyof typeof sharedLabels.filters][] = [
  ['creation_date', 'creation_date'],
  ['applied_date', 'applied_date']
]

const store = useStore()
const isLoading = ref(false)
const fetchData = async () => {
  isLoading.value = true
  const params = {
    page: page.value,
    page_size: paginateBy.value,
    q: query.value,
    ordering: orderingString.value
  }

  try {
    const response = await axios.get('manage/moderation/reports/', {
      params
    })

    result.value = response.data
    if (query.value === 'resolved:no') {
      console.log('Refreshing sidebar notifications')
      store.commit('ui/incrementNotifications', {
        type: 'pendingReviewReports',
        value: response.data.count
      })
    }
  } catch (error) {
    useErrorHandler(error as Error)
    result.value = null
  } finally {
    isLoading.value = false
  }
}

onSearch(() => (page.value = 1))
watch(page, fetchData)
onOrderingUpdate(fetchData)
fetchData()

const { $pgettext } = useGettext()
const sharedLabels = useSharedLabels()
const labels = computed(() => ({
  searchPlaceholder: $pgettext('Content/Search/Input.Placeholder', 'Search by account, summary, domain…'),
  reports: $pgettext('*/Moderation/*/Noun', 'Reports')
}))
</script>

<template>
  <main v-title="labels.reports">
    <section class="ui vertical stripe segment">
      <h2 class="ui header">
        <translate translate-context="*/Moderation/*/Noun">
          Reports
        </translate>
      </h2>
      <div class="ui hidden divider" />
      <div class="ui inline form">
        <div class="fields">
          <div class="ui field">
            <label for="reports-search"><translate translate-context="Content/Search/Input.Label/Noun">Search</translate></label>
            <form @submit.prevent="query = search.value">
              <input
                id="reports-search"
                ref="search"
                name="search"
                type="text"
                :value="query"
                :placeholder="labels.searchPlaceholder"
              >
            </form>
          </div>
          <div class="field">
            <label for="reports-status"><translate translate-context="*/*/*">Status</translate></label>
            <select
              id="reports-status"
              class="ui dropdown"
              :value="getTokenValue('resolved', '')"
              @change="addSearchToken('resolved', ($event.target as HTMLSelectElement).value)"
            >
              <option value="">
                <translate translate-context="Content/*/Dropdown">
                  All
                </translate>
              </option>
              <option value="yes">
                <translate translate-context="Content/*/*/Short">
                  Resolved
                </translate>
              </option>
              <option value="no">
                <translate translate-context="Content/*/*/Short">
                  Unresolved
                </translate>
              </option>
            </select>
          </div>
          <report-category-dropdown
            class="field"
            :all="true"
            :label="true"
            :model-value="getTokenValue('category', '')"
            @update:model-value="addSearchToken('category', $event)"
          />
          <div class="field">
            <label for="reports-ordering"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering</translate></label>
            <select
              id="reports-ordering"
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
            <label for="reports-ordering-direction"><translate translate-context="Content/Search/Dropdown.Label/Noun">Order</translate></label>
            <select
              id="reports-ordering-direction"
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
        </div>
      </div>
      <div
        v-if="isLoading"
        class="ui active inverted dimmer"
      >
        <div class="ui loader" />
      </div>
      <div v-else-if="!result || result.count === 0">
        <empty-state
          :refresh="true"
          @refresh="fetchData()"
        />
      </div>
      <div v-else-if="mode === 'card'">
        <report-card
          v-for="obj in result.results"
          :key="obj.uuid"
          :init-obj="obj"
          @handled="fetchData"
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
