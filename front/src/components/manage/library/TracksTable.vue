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
  ['creation_date', 'creation_date']
]

const { t } = useI18n()
const actionFilters = computed(() => ({ q: query.value, ...props.filters }))
const actions = computed(() => [
  {
    name: 'delete',
    label: t('components.manage.library.TracksTable.action.delete.label'),
    confirmationMessage: t('components.manage.library.TracksTable.action.delete.warning'),
    isDangerous: true,
    allowAll: false,
    confirmColor: 'danger'
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
    const response = await axios.get('/manage/library/tracks/', {
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
  searchPlaceholder: t('components.manage.library.TracksTable.placeholder.search')
}))
</script>

<template>
  <div>
    <div class="ui inline form">
      <div class="fields">
        <div class="ui six wide field">
          <label for="tracks-search">{{ $t('components.manage.library.TracksTable.label.search') }}</label>
          <form @submit.prevent="query = search.value">
            <input
              id="tracks-search"
              ref="search"
              name="search"
              type="text"
              :value="query"
              :placeholder="labels.searchPlaceholder"
            >
          </form>
        </div>
        <div class="field">
          <label for="tracks-ordering">{{ $t('components.manage.library.TracksTable.ordering.label') }}</label>
          <select
            id="tracks-ordering"
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
          <label for="tracks-ordering-direction">{{ $t('components.manage.library.TracksTable.ordering.direction.label') }}</label>
          <select
            id="tracks-ordering-direction"
            v-model="orderingDirection"
            class="ui dropdown"
          >
            <option value="+">
              {{ $t('components.manage.library.TracksTable.ordering.direction.ascending') }}
            </option>
            <option value="-">
              {{ $t('components.manage.library.TracksTable.ordering.direction.descending') }}
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
        action-url="manage/library/tracks/action/"
        :filters="actionFilters"
        @action-launched="fetchData"
      >
        <template #header-cells>
          <th>
            {{ $t('components.manage.library.TracksTable.table.track.header.title') }}
          </th>
          <th>
            {{ $t('components.manage.library.TracksTable.table.track.header.album') }}
          </th>
          <th>
            {{ $t('components.manage.library.TracksTable.table.track.header.artist') }}
          </th>
          <th>
            {{ $t('components.manage.library.TracksTable.table.track.header.domain') }}
          </th>
          <th>
            {{ $t('components.manage.library.TracksTable.table.track.header.license') }}
          </th>
          <th>
            {{ $t('components.manage.library.TracksTable.table.track.header.creationDate') }}
          </th>
        </template>
        <template
          #row-cells="scope"
        >
          <td>
            <router-link :to="{name: 'manage.library.tracks.detail', params: {id: scope.obj.id }}">
              {{ scope.obj.title }}
            </router-link>
          </td>
          <td>
            <template v-if="scope.obj.album">
              <router-link :to="{name: 'manage.library.albums.detail', params: {id: scope.obj.album.id }}">
                <i class="wrench icon" />
              </router-link>
              <a
                href=""
                class="discrete link"
                :title="scope.obj.album.title"
                @click.prevent="addSearchToken('album_id', scope.obj.album.id)"
              >{{ scope.obj.album.title }}</a>
            </template>
          </td>
          <td>
            <router-link :to="{name: 'manage.library.artists.detail', params: {id: scope.obj.artist.id }}">
              <i class="wrench icon" />
            </router-link>
            <a
              href=""
              class="discrete link"
              :title="scope.obj.artist.name"
              @click.prevent="addSearchToken('artist_id', scope.obj.artist.id)"
            >{{ scope.obj.artist.name }}</a>
          </td>
          <td>
            <template v-if="!scope.obj.is_local">
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
              {{ $t('components.manage.library.TracksTable.link.local') }}
            </a>
          </td>
          <td>
            <a
              v-if="scope.obj.license"
              href=""
              class="discrete link"
              :title="scope.obj.license"
              @click.prevent="addSearchToken('license', scope.obj.license)"
            >{{ scope.obj.license }}</a>
            <span v-else>
              {{ $t('components.manage.library.TracksTable.notApplicable') }}
            </span>
          </td>
          <td>
            <human-date :date="scope.obj.creation_date" />
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
        {{ $t('components.manage.library.TracksTable.pagination.results', {start: ((page-1) * paginateBy) + 1, end: ((page-1) * paginateBy) + result.results.length, total: result.count}) }}
      </span>
    </div>
  </div>
</template>
