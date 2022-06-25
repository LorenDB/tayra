<script setup lang="ts">
import axios from 'axios'
import Pagination from '~/components/vui/Pagination.vue'
import UserRequestCard from '~/components/manage/moderation/UserRequestCard.vue'
import useSharedLabels from '~/composables/locale/useSharedLabels'
import useOrdering, { OrderingProps } from '~/composables/useOrdering'
import useSmartSearch, { SmartSearchProps } from '~/composables/useSmartSearch'
import { ref, computed, watch } from 'vue'
import { OrderingField } from '~/store/ui'
import { useGettext } from 'vue3-gettext'
import { useStore } from '~/store'

interface Props extends SmartSearchProps, OrderingProps {}

const props = withDefaults(defineProps<Props>(), {
  defaultQuery: '',
  updateUrl: false
})

// TODO (wvffle): Make sure everything is it's own type
const page = ref(1)
type ResponseType = { count: number, results: any[] }
const result = ref<null | ResponseType>(null)

const { onSearch, query, addSearchToken, getTokenValue } = useSmartSearch(props.defaultQuery, props.updateUrl)
const { onOrderingUpdate, orderingString, paginateBy, ordering, orderingDirection } = useOrdering(props.orderingConfigName)

const orderingOptions: [OrderingField, keyof typeof sharedLabels.filters][] = [
  ['creation_date', 'creation_date'],
  ['handled_date', 'handled_date']
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
    const response = await axios.get('manage/moderation/requests/', {
      params
      // TODO (wvffle): Check if params should be serialized. In other similar components (Podcasts, Artists) they are
      // paramsSerializer: function (params) {
      //   return qs.stringify(params, { indices: false })
      // }
    })

    result.value = response.data

    if (query.value === 'status:pending') {
      store.commit('ui/incrementNotifications', {
        type: 'pendingReviewRequests',
        value: response.data.count
      })
    }
  } catch (error) {
    // TODO (wvffle): Handle error
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
  searchPlaceholder: $pgettext('Content/Search/Input.Placeholder', 'Search by username…'),
  reports: $pgettext('*/Moderation/*/Noun', 'User Requests')
}))
</script>

<template>
  <main v-title="labels.reports">
    <section class="ui vertical stripe segment">
      <h2 class="ui header">
        <translate translate-context="*/Moderation/*/Noun">
          User Requests
        </translate>
      </h2>
      <div class="ui hidden divider" />
      <div class="ui inline form">
        <div class="fields">
          <div class="ui field">
            <label for="requests-search"><translate translate-context="Content/Search/Input.Label/Noun">Search</translate></label>
            <form @submit.prevent="query = $refs.search.value">
              <input
                id="requests-search"
                ref="search"
                name="search"
                type="text"
                :value="query"
                :placeholder="labels.searchPlaceholder"
              >
            </form>
          </div>
          <div class="field">
            <label for="requests-status"><translate translate-context="*/*/*">Status</translate></label>
            <select
              id="requests-status"
              class="ui dropdown"
              :value="getTokenValue('status', '')"
              @change="addSearchToken('status', ($event.target as HTMLSelectElement).value)"
            >
              <option value="">
                <translate translate-context="Content/*/Dropdown">
                  All
                </translate>
              </option>
              <option value="pending">
                <translate translate-context="Content/Library/*/Short">
                  Pending
                </translate>
              </option>
              <option value="approved">
                <translate translate-context="Content/*/*/Short">
                  Approved
                </translate>
              </option>
              <option value="refused">
                <translate translate-context="Content/*/*/Short">
                  Refused
                </translate>
              </option>
            </select>
          </div>
          <div class="field">
            <label for="requests-ordering"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering</translate></label>
            <select
              id="requests-ordering"
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
            <label for="requests-ordering-direction"><translate translate-context="Content/Search/Dropdown.Label/Noun">Order</translate></label>
            <select
              id="requests-ordering-direction"
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
      <template v-else>
        <user-request-card
          v-for="obj in result.results"
          :key="obj.uuid"
          :init-obj="obj"
          @handled="fetchData"
        />
        <div class="ui center aligned basic segment">
          <pagination
            v-if="result.count > paginateBy"
            v-model:current="page"
            :paginate-by="paginateBy"
            :total="result.count"
          />
        </div>
      </template>
    </section>
  </main>
</template>
