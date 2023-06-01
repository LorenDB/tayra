<script setup lang="ts">
import type { SmartSearchProps } from '~/composables/navigation/useSmartSearch'
import type { OrderingProps } from '~/composables/navigation/useOrdering'
import type { RouteRecordName } from 'vue-router'
import type { OrderingField } from '~/store/ui'

import { ref, computed, watch } from 'vue'
import { useI18n } from 'vue-i18n'

import axios from 'axios'

import useSharedLabels from '~/composables/locale/useSharedLabels'
import ActionTable from '~/components/common/ActionTable.vue'
import Pagination from '~/components/vui/Pagination.vue'

import useSmartSearch from '~/composables/navigation/useSmartSearch'
import useOrdering from '~/composables/navigation/useOrdering'
import useErrorHandler from '~/composables/useErrorHandler'
import usePage from '~/composables/navigation/usePage'

interface Props extends SmartSearchProps, OrderingProps {
  filters?: object

  // TODO(wvffle): Remove after https://github.com/vuejs/core/pull/4512 is merged
  orderingConfigName?: RouteRecordName
  defaultQuery?: string
  updateUrl?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  defaultQuery: '',
  updateUrl: false,
  filters: () => ({}),
  orderingConfigName: undefined
})

const search = ref()

const page = usePage()
type ResponseType = { count: number, results: any[] }
const result = ref<null | ResponseType>(null)

const { onSearch, query, addSearchToken } = useSmartSearch(props)
const { onOrderingUpdate, orderingString, paginateBy, ordering, orderingDirection } = useOrdering(props)

const orderingOptions: [OrderingField, keyof typeof sharedLabels.filters][] = [
  ['creation_date', 'first_seen'],
  ['last_fetch_date', 'last_seen'],
  ['preferred_username', 'username'],
  ['domain', 'domain'],
  ['uploads_count', 'uploads']
]

const { t } = useI18n()
const actionFilters = computed(() => ({ q: query.value, ...props.filters }))
const actions = computed(() => [
  {
    name: 'purge',
    label: t('components.manage.moderation.AccountsTable.action.purge.label'),
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

const sharedLabels = useSharedLabels()
const labels = computed(() => ({
  searchPlaceholder: t('components.manage.moderation.AccountsTable.placeholder.search')
}))
</script>

<template>
  <div>
    <div class="ui inline form">
      <div class="fields">
        <div class="ui six wide field">
          <label for="accounts-search">{{ $t('components.manage.moderation.AccountsTable.label.search') }}</label>
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
          <label for="accounts-ordering">{{ $t('components.manage.moderation.AccountsTable.ordering.label') }}</label>
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
          <label for="accounts-ordering-direction">{{ $t('components.manage.moderation.AccountsTable.ordering.direction.label') }}</label>
          <select
            id="accounts-ordering-direction"
            v-model="orderingDirection"
            class="ui dropdown"
          >
            <option value="+">
              {{ $t('components.manage.moderation.AccountsTable.ordering.direction.ascending') }}
            </option>
            <option value="-">
              {{ $t('components.manage.moderation.AccountsTable.ordering.direction.descending') }}
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
            {{ $t('components.manage.moderation.AccountsTable.table.account.header.name') }}
          </th>
          <th>
            {{ $t('components.manage.moderation.AccountsTable.table.account.header.domain') }}
          </th>
          <th>
            {{ $t('components.manage.moderation.AccountsTable.table.account.header.uploads') }}
          </th>
          <th>
            {{ $t('components.manage.moderation.AccountsTable.table.account.header.firstSeen') }}
          </th>
          <th>
            {{ $t('components.manage.moderation.AccountsTable.table.account.header.lastSeen') }}
          </th>
          <th>
            {{ $t('components.manage.moderation.AccountsTable.table.account.header.moderationRule') }}
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
              {{ $t('components.manage.moderation.AccountsTable.link.local') }}
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
            <span v-if="scope.obj.instance_policy"><i class="shield icon" />{{ $t('components.manage.moderation.AccountsTable.table.account.moderationRule') }}</span>
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
        {{ $t('components.manage.moderation.AccountsTable.pagination.results', {start: ((page-1) * paginateBy) + 1, end: ((page-1) * paginateBy) + result.results.length, total: result.count}) }}
      </span>
    </div>
  </div>
</template>
