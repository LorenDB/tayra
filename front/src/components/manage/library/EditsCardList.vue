<script setup lang="ts">
import type { SmartSearchProps } from '~/composables/navigation/useSmartSearch'
import type { EditObjectType } from '~/composables/moderation/useEditConfigs'
import type { OrderingProps } from '~/composables/navigation/useOrdering'
import type { ReviewState, Review } from '~/types'
import type { RouteRecordName } from 'vue-router'
import type { OrderingField } from '~/store/ui'

import { ref, reactive, watch, computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { uniq } from 'lodash-es'

import axios from 'axios'

import Pagination from '~/components/vui/Pagination.vue'
import EditCard from '~/components/library/EditCard.vue'

import useEditConfigs from '~/composables/moderation/useEditConfigs'
import useSmartSearch from '~/composables/navigation/useSmartSearch'
import useSharedLabels from '~/composables/locale/useSharedLabels'
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

const configs = useEditConfigs()
const search = ref()

const page = usePage()

type StateTarget = Review['target']
type ResponseType = { count: number, results: Review[] }
const result = ref<null | ResponseType>(null)

const { onSearch, query, addSearchToken, getTokenValue } = useSmartSearch(props)
const { onOrderingUpdate, orderingString, paginateBy, ordering, orderingDirection } = useOrdering(props)

const orderingOptions: [OrderingField, keyof typeof sharedLabels.filters][] = [
  ['creation_date', 'creation_date'],
  ['applied_date', 'applied_date']
]

interface TargetType {
  payload: Review
  currentState: Record<EditObjectType, { value: unknown }>
}

type Targets = Exclude<StateTarget, undefined>['type']
const targets = reactive({
  track: {}
}) as Record<Targets, Record<string, TargetType>>

const fetchTargets = async () => {
  // we request target data via the API so we can display previous state
  // additional data next to the edit card
  type Config = { url: string, ids: number[] }
  const typesAndIds: Record<Targets, Config> = {
    artist: { url: 'artists/', ids: [] },
    track: { url: 'tracks/', ids: [] },
    album: { url: 'albums/', ids: [] }
  }

  for (const res of result.value?.results ?? []) {
    if (!res.target) continue
    const typeAndId = typesAndIds[res.target.type as keyof typeof typesAndIds]
    typeAndId?.ids.push(res.target.id)
  }

  for (const [key, config] of Object.entries(typesAndIds)) {
    if (config.ids.length === 0) {
      continue
    }

    const response = await axios.get(config.url, {
      params: {
        id: uniq(config.ids),
        hidden: 'null'
      }
    }).catch((error) => {
      useErrorHandler(error as Error)
    })

    for (const payload of response?.data?.results ?? []) {
      targets[key as keyof typeof targets][payload.id] = {
        payload,
        currentState: configs[key as keyof typeof targets].fields.reduce((state, field) => {
          // TODO (wvffle): This cast may result in an `undefined` key added, make sure to test that.
          state[field.id as EditObjectType] = { value: field.getValue(payload) }
          return state
        }, {} as Record<EditObjectType, { value: unknown }>)
      }
    }
  }
}

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
    const response = await axios.get('mutations/', {
      params
    })

    result.value = response.data
    fetchTargets()
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

const { t } = useI18n()
const sharedLabels = useSharedLabels()
const labels = computed(() => ({
  searchPlaceholder: t('components.manage.library.EditsCardList.placeholder.search')
}))

const handle = (type: 'delete' | 'approved', id: string, value: boolean) => {
  for (const entry of result.value?.results ?? []) {
    if (entry.uuid === id) {
      entry.is_approved = value
    }
  }
}

const getCurrentState = (target?: StateTarget): ReviewState => {
  if (!target || !(target.type in targets)) return {}
  return targets[target.type]?.[target.id]?.currentState ?? {}
}
</script>

<template>
  <div class="ui text container">
    <slot />
    <div class="ui inline form">
      <div class="fields">
        <div class="ui field">
          <label for="search-edits">{{ $t('components.manage.library.EditsCardList.label.search') }}</label>
          <form @submit.prevent="query = search.value">
            <input
              id="search-edits"
              ref="search"
              name="search"
              type="text"
              :value="query"
              :placeholder="labels.searchPlaceholder"
            >
          </form>
        </div>
        <div class="field">
          <label for="edit-status">{{ $t('components.manage.library.EditsCardList.label.status') }}</label>
          <select
            id="edit-status"
            class="ui dropdown"
            :value="getTokenValue('is_approved', '')"
            @change="addSearchToken('is_approved', ($event.target as HTMLSelectElement).value)"
          >
            <option value="">
              {{ $t('components.manage.library.EditsCardList.option.all') }}
            </option>
            <option value="null">
              {{ $t('components.manage.library.EditsCardList.option.pending') }}
            </option>
            <option value="yes">
              {{ $t('components.manage.library.EditsCardList.option.approved') }}
            </option>
            <option value="no">
              {{ $t('components.manage.library.EditsCardList.option.rejected') }}
            </option>
          </select>
        </div>
        <div class="field">
          <label for="edit-ordering">{{ $t('components.manage.library.EditsCardList.ordering.label') }}</label>
          <select
            id="edit-ordering"
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
          <label for="edit-ordering-direction">{{ $t('components.manage.library.EditsCardList.ordering.direction.label') }}</label>
          <select
            id="edit-ordering-direction"
            v-model="orderingDirection"
            class="ui dropdown"
          >
            <option value="+">
              {{ $t('components.manage.library.EditsCardList.ordering.direction.ascending') }}
            </option>
            <option value="-">
              {{ $t('components.manage.library.EditsCardList.ordering.direction.descending') }}
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
      <div v-else-if="(result?.count ?? 0) > 0">
        <edit-card
          v-for="obj in result?.results ?? []"
          :key="obj.uuid"
          :obj="obj"
          :current-state="getCurrentState(obj.target)"
          @deleted="handle('delete', obj.uuid, false)"
          @approved="handle('approved', obj.uuid, $event)"
        />
      </div>
      <empty-state
        v-else
        :refresh="true"
        @refresh="fetchData()"
      />
    </div>
    <div class="ui hidden divider" />
    <div>
      <pagination
        v-if="result && result.count > paginateBy"
        v-model:current="page"
        :compact="true"
        :paginate-by="paginateBy"
        :total="result.count"
      />

      <span v-if="result && result.results.length > 0">
        {{ $t('components.manage.library.EditsCardList.pagination.results', {start: ((page-1) * paginateBy) + 1, end: ((page-1) * paginateBy) + result.results.length, total: result.count}) }}
      </span>
    </div>
  </div>
</template>
