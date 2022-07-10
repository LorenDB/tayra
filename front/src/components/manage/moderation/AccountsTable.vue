<script setup lang="ts">
import type { RouteWithPreferences, OrderingField } from '~/store/ui'
import type { OrderingProps } from '~/composables/useOrdering'
import type { SmartSearchProps } from '~/composables/useSmartSearch'

import axios from 'axios'
import Pagination from '~/components/vui/Pagination.vue'
import ActionTable from '~/components/common/ActionTable.vue'
import useSharedLabels from '~/composables/locale/useSharedLabels'
import { ref, computed, watch } from 'vue'
import { useGettext } from 'vue3-gettext'
import useOrdering from '~/composables/useOrdering'
import useSmartSearch from '~/composables/useSmartSearch'

interface Props extends SmartSearchProps, OrderingProps {
  // TODO (wvffle): find object type
  filters?: object

  // TODO(wvffle): Remove after https://github.com/vuejs/core/pull/4512 is merged
  orderingConfigName: RouteWithPreferences | null
  defaultQuery?: string
  updateUrl?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  defaultQuery: '',
  updateUrl: false,
  filters: () => ({})
})

const search = ref()

// TODO (wvffle): Make sure everything is it's own type
const page = ref(1)
type ResponseType = { count: number, results: any[] }
const result = ref<null | ResponseType>(null)

const { onSearch, query, addSearchToken } = useSmartSearch(props.defaultQuery, props.updateUrl)
const { onOrderingUpdate, orderingString, paginateBy, ordering, orderingDirection } = useOrdering(props.orderingConfigName)

const orderingOptions: [OrderingField, keyof typeof sharedLabels.filters][] = [
  ['creation_date', 'first_seen'],
  ['last_fetch_date', 'last_seen'],
  ['preferred_username', 'username'],
  ['domain', 'domain'],
  ['uploads_count', 'uploads']
]

const { $pgettext } = useGettext()
const actionFilters = computed(() => ({ q: query.value, ...props.filters }))
const actions = computed(() => [
  {
    name: 'purge',
    label: $pgettext('*/*/*/Verb', 'Purge'),
    isDangerous: true
  }
])

const isLoading = ref(false)
const fetchData = async () => {
  isLoading.value = true
  const params = {
    page: page.value,
    page_size: paginateBy.value,
    q: query.value,
    ordering: orderingString.value,
    ...props.filters
  }

  try {
    const response = await axios.get('/manage/accounts/', {
      params
    })

    result.value = response.data
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

const sharedLabels = useSharedLabels()
const labels = computed(() => ({
  searchPlaceholder: $pgettext('Content/Search/Input.Placeholder', 'Search by domain, username, bio…')
}))
</script>

<template>
  <div>
    <div class="ui inline form">
      <div class="fields">
        <div class="ui six wide field">
          <label for="accounts-search"><translate translate-context="Content/Search/Input.Label/Noun">Search</translate></label>
          <form @submit.prevent="query = search.value">
            <input
              id="accounts-search"
              ref="search"
              name="search"
              type="text"
              :value="query"
              :placeholder="labels.searchPlaceholder"
            >
          </form>
        </div>
        <div class="field">
          <label for="accounts-ordering"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering</translate></label>
          <select
            id="accounts-ordering"
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
          <label for="accounts-ordering-direction"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering direction</translate></label>
          <select
            id="accounts-ordering-direction"
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
    <div class="dimmable">
      <div
        v-if="isLoading"
        class="ui active inverted dimmer"
      >
        <div class="ui loader" />
      </div>
      <action-table
        v-if="result"
        :objects-data="result"
        :actions="actions"
        action-url="manage/accounts/action/"
        :filters="actionFilters"
        @action-launched="fetchData"
      >
        <template #header-cells>
          <th>
            <translate translate-context="*/*/*/Noun">
              Name
            </translate>
          </th>
          <th>
            <translate translate-context="Content/Moderation/*/Noun">
              Domain
            </translate>
          </th>
          <th>
            <translate translate-context="*/*/*">
              Uploads
            </translate>
          </th>
          <th>
            <translate translate-context="Content/Moderation/Table.Label/Short (Value is a date)">
              First seen
            </translate>
          </th>
          <th>
            <translate translate-context="Content/Moderation/Table.Label/Noun">
              Last seen
            </translate>
          </th>
          <th>
            <translate translate-context="Content/Moderation/Table.Label/Short">
              Under moderation rule
            </translate>
          </th>
        </template>
        <template
          #row-cells="scope"
        >
          <td>
            <router-link :to="{name: 'manage.moderation.accounts.detail', params: {id: scope.obj.full_username }}">
              {{ scope.obj.preferred_username }}
            </router-link>
          </td>
          <td>
            <template v-if="!scope.obj.user">
              <router-link :to="{name: 'manage.moderation.domains.detail', params: {id: scope.obj.domain }}">
                <i class="wrench icon" />
              </router-link>
              <a
                href=""
                class="discrete link"
                :title="scope.obj.domain"
                @click.prevent="addSearchToken('domain', scope.obj.domain)"
              >{{ scope.obj.domain }}</a>
            </template>
            <a
              v-else
              href=""
              class="ui tiny accent icon link label"
              @click.prevent="addSearchToken('domain', scope.obj.domain)"
            >
              <i class="home icon" />
              <translate translate-context="Content/Moderation/*/Short, Noun">Local account</translate>
            </a>
          </td>
          <td>
            {{ scope.obj.uploads_count }}
          </td>
          <td>
            <human-date :date="scope.obj.creation_date" />
          </td>
          <td>
            <human-date
              v-if="scope.obj.last_fetch_date"
              :date="scope.obj.last_fetch_date"
            />
          </td>
          <td>
            <span v-if="scope.obj.instance_policy"><i class="shield icon" /> <translate translate-context="*/*/*">Yes</translate></span>
          </td>
        </template>
      </action-table>
    </div>
    <div>
      <pagination
        v-if="result && result.count > paginateBy"
        v-model:current="page"
        :compact="true"
        :paginate-by="paginateBy"
        :total="result.count"
      />

      <span v-if="result && result.results.length > 0">
        <translate
          translate-context="Content/*/Paragraph"
          :translate-params="{start: ((page-1) * paginateBy) + 1, end: ((page-1) * paginateBy) + result.results.length, total: result.count}"
        >
          Showing results %{ start }-%{ end } on %{ total }
        </translate>
      </span>
    </div>
  </div>
</template>
