<script setup lang="ts">
import type { OrderingProps } from '~/composables/navigation/useOrdering'
import type { RouteRecordName } from 'vue-router'
import type { OrderingField } from '~/store/ui'

import { watchDebounced } from '@vueuse/core'
import { computed, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'

import axios from 'axios'

import ActionTable from '~/components/common/ActionTable.vue'
import Pagination from '~/components/vui/Pagination.vue'

import useSharedLabels from '~/composables/locale/useSharedLabels'
import useOrdering from '~/composables/navigation/useOrdering'
import useErrorHandler from '~/composables/useErrorHandler'
import usePage from '~/composables/navigation/usePage'

interface Props extends OrderingProps {
  filters?: object
  allowListEnabled?: boolean

  // TODO(wvffle): Remove after https://github.com/vuejs/core/pull/4512 is merged
  orderingConfigName?: RouteRecordName
}

const props = withDefaults(defineProps<Props>(), {
  filters: () => ({}),
  allowListEnabled: false,
  orderingConfigName: undefined
})

const page = usePage()
type ResponseType = { count: number, results: any[] }
const result = ref<null | ResponseType>(null)

const { onOrderingUpdate, orderingString, paginateBy, ordering, orderingDirection } = useOrdering(props)

const orderingOptions: [OrderingField, keyof typeof sharedLabels.filters][] = [
  ['name', 'name'],
  ['creation_date', 'first_seen'],
  ['actors_count', 'users'],
  ['outbox_activities_count', 'received_messages']
]

const { t } = useI18n()
const query = ref('')
const actionFilters = computed(() => ({ q: query.value, ...props.filters }))
const actions = computed(() => [
  {
    name: 'purge',
    label: t('components.manage.moderation.DomainsTable.action.purge.label'),
    isDangerous: true
  },
  {
    name: 'allow_list_add',
    label: t('components.manage.moderation.DomainsTable.action.add.label'),
    filterCheckable: (obj: { allowed: boolean }) => {
      return !obj.allowed
    }
  },
  {
    name: 'allow_list_remove',
    label: t('components.manage.moderation.DomainsTable.action.remove.label'),
    filterCheckable: (obj: { allowed: boolean }) => {
      return obj.allowed
    }
  }
])

const allowed = ref(null)
const isLoading = ref(false)
const fetchData = async () => {
  isLoading.value = true
  const params = {
    page: page.value,
    page_size: paginateBy.value,
    q: query.value,
    ordering: orderingString.value,
    allowed: allowed.value,
    ...props.filters
  } as Record<string, unknown>

  if (params.allowed === null) {
    delete params.allowed
  }

  try {
    const response = await axios.get('/manage/federation/domains/', {
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

const forceFetchFirstPage = async () => {
  page.value = 1
  return fetchData()
}

watchDebounced(query, forceFetchFirstPage, { debounce: 300 })
onOrderingUpdate(forceFetchFirstPage)
watch(allowed, forceFetchFirstPage)

watch(page, fetchData)
fetchData()

const sharedLabels = useSharedLabels()
const labels = computed(() => ({
  searchPlaceholder: t('components.manage.moderation.DomainsTable.placeholder.search'),
  allowListTitle: t('components.manage.moderation.DomainsTable.link.list')
}))
</script>

<template>
  <div>
    <div class="ui inline form">
      <div class="fields">
        <div class="ui field">
          <label for="domains-search">{{ $t('components.manage.moderation.DomainsTable.label.search') }}</label>
          <input
            id="domains-search"
            v-model="query"
            name="search"
            type="text"
            :placeholder="labels.searchPlaceholder"
          >
        </div>
        <div
          v-if="allowListEnabled"
          class="field"
        >
          <label for="domains-allow-list">{{ $t('components.manage.moderation.DomainsTable.label.inList') }}</label>
          <select
            id="domains-allow-list"
            v-model="allowed"
            class="ui dropdown"
          >
            <option :value="null">
              {{ $t('components.manage.moderation.DomainsTable.option.all') }}
            </option>
            <option :value="true">
              {{ $t('components.manage.moderation.DomainsTable.option.yes') }}
            </option>
            <option :value="false">
              {{ $t('components.manage.moderation.DomainsTable.option.no') }}
            </option>
          </select>
        </div>
        <div class="field">
          <label for="domains-ordering">{{ $t('components.manage.moderation.DomainsTable.ordering.label') }}</label>
          <select
            id="domains-ordering"
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
          <label for="domains-ordering-direction">{{ $t('components.manage.moderation.DomainsTable.ordering.direction.label') }}</label>
          <select
            id="domains-ordering-direction"
            v-model="orderingDirection"
            class="ui dropdown"
          >
            <option value="+">
              {{ $t('components.manage.moderation.DomainsTable.ordering.direction.ascending') }}
            </option>
            <option value="-">
              {{ $t('components.manage.moderation.DomainsTable.ordering.direction.descending') }}
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
        v-if="result && result.results.length > 0"
        :objects-data="result"
        :actions="actions"
        action-url="manage/federation/domains/action/"
        id-field="name"
        :filters="actionFilters"
        @action-launched="fetchData"
      >
        <template #header-cells>
          <th>
            {{ $t('components.manage.moderation.DomainsTable.table.domain.header.name') }}
          </th>
          <th>
            {{ $t('components.manage.moderation.DomainsTable.table.domain.header.users') }}
          </th>
          <th>
            {{ $t('components.manage.moderation.DomainsTable.table.domain.header.receivedMessages') }}
          </th>
          <th>
            {{ $t('components.manage.moderation.DomainsTable.table.domain.header.firstSeen') }}
          </th>
          <th>
            {{ $t('components.manage.moderation.DomainsTable.table.domain.header.moderationRule') }}
          </th>
        </template>
        <template
          #row-cells="scope"
        >
          <td>
            <router-link :to="{name: 'manage.moderation.domains.detail', params: {id: scope.obj.name }}">
              {{ scope.obj.name }}
              <i
                v-if="allowListEnabled && scope.obj.allowed"
                class="success check icon"
                :title="labels.allowListTitle"
              />
            </router-link>
          </td>
          <td>
            {{ scope.obj.actors_count }}
          </td>
          <td>
            {{ scope.obj.outbox_activities_count }}
          </td>
          <td>
            <human-date :date="scope.obj.creation_date" />
          </td>
          <td>
            <span v-if="scope.obj.instance_policy"><i class="shield icon" />{{ $t('components.manage.moderation.DomainsTable.table.domain.moderationRule') }}</span>
          </td>
        </template>
      </action-table>
      <div
        v-else
        class="ui placeholder segment"
      >
        <div class="ui icon header">
          <i class="server icon" />
          {{ $t('components.manage.moderation.DomainsTable.empty.noPods') }}
        </div>
      </div>
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
        {{ $t('components.manage.moderation.DomainsTable.pagination.results', {start: ((page-1) * paginateBy) + 1, end: ((page-1) * paginateBy) + result.results.length, total: result.count}) }}
      </span>
    </div>
  </div>
</template>
