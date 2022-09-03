<script setup lang="ts">
import type { SmartSearchProps } from '~/composables/navigation/useSmartSearch'
import type { OrderingProps } from '~/composables/navigation/useOrdering'
import type { RouteRecordName } from 'vue-router'
import type { OrderingField } from '~/store/ui'

import { ref, computed, watch } from 'vue'
import { useGettext } from 'vue3-gettext'

import axios from 'axios'

import ActionTable from '~/components/common/ActionTable.vue'
import Pagination from '~/components/vui/Pagination.vue'

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

const search = ref()

const page = usePage()
type ResponseType = { count: number, results: any[] }
const result = ref<null | ResponseType>(null)

const { onSearch, query, addSearchToken, getTokenValue } = useSmartSearch(props)
const { onOrderingUpdate, orderingString, paginateBy, ordering, orderingDirection } = useOrdering(props)

const orderingOptions: [OrderingField, keyof typeof sharedLabels.filters][] = [
  ['creation_date', 'creation_date'],
  ['name', 'name']
]

const actionFilters = computed(() => ({ q: query.value, ...props.filters }))
const actions = computed(() => [
  {
    name: 'delete',
    label: $pgettext('*/*/*/Verb', 'Delete'),
    confirmationMessage: $pgettext('Popup/*/Paragraph', 'The selected artist will be removed, as well as associated uploads, tracks, albums, favorites and listening history. This action is irreversible.'),
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
    const response = await axios.get('/manage/library/artists/', {
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
const { $pgettext } = useGettext()
const labels = computed(() => ({
  searchPlaceholder: $pgettext('Content/Search/Input.Placeholder', 'Search by domain, name, MusicBrainz ID…')
}))

const getUrl = (artist: { channel?: number; id: number }) => {
  return artist.channel
    ? { name: 'manage.channels.detail', params: { id: artist.channel } }
    : { name: 'manage.library.artists.detail', params: { id: artist.id } }
}
</script>

<template>
  <div>
    <div class="ui inline form">
      <div class="fields">
        <div class="ui six wide field">
          <label for="artists-serarch"><translate translate-context="Content/Search/Input.Label/Noun">Search</translate></label>
          <form @submit.prevent="query = search.value">
            <input
              id="artists-search"
              ref="search"
              name="search"
              type="text"
              :value="query"
              :placeholder="labels.searchPlaceholder"
            >
          </form>
        </div>
        <div class="field">
          <label for="artists-category"><translate translate-context="*/*/*">Category</translate></label>
          <select
            id="artists-category"
            class="ui dropdown"
            :value="getTokenValue('category', '')"
            @change="addSearchToken('category', ($event.target as HTMLSelectElement).value)"
          >
            <option value="">
              <translate translate-context="Content/*/Dropdown">
                All
              </translate>
            </option>
            <option value="podcast">
              {{ sharedLabels.fields.content_category.choices.podcast }}
            </option>
            <option value="music">
              {{ sharedLabels.fields.content_category.choices.music }}
            </option>
            <option value="other">
              {{ sharedLabels.fields.content_category.choices.other }}
            </option>
          </select>
        </div>
        <div class="field">
          <label for="artists-ordering"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering</translate></label>
          <select
            id="artists-ordering"
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
          <label for="artists-ordering-direction"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering direction</translate></label>
          <select
            id="artists-ordering-direction"
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
        action-url="manage/library/artists/action/"
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
              Albums
            </translate>
          </th>
          <th>
            <translate translate-context="*/*/*">
              Tracks
            </translate>
          </th>
          <th>
            <translate translate-context="Content/*/*/Noun">
              Creation date
            </translate>
          </th>
        </template>
        <template
          #row-cells="scope"
        >
          <td>
            <router-link :to="getUrl(scope.obj)">
              {{ scope.obj.name }}
            </router-link>
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
              <translate translate-context="Content/Moderation/*/Short, Noun">Local</translate>
            </a>
          </td>
          <td>
            {{ scope.obj.albums_count }}
          </td>
          <td>
            {{ scope.obj.tracks_count }}
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
