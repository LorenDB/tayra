<script setup lang="ts">
import type { RouteWithPreferences, OrderingField } from '~/store/ui'
import type { SmartSearchProps } from '~/composables/useSmartSearch'
import type { OrderingProps } from '~/composables/useOrdering'

import axios from 'axios'
import Pagination from '~/components/vui/Pagination.vue'
import ActionTable from '~/components/common/ActionTable.vue'
import useSharedLabels from '~/composables/locale/useSharedLabels'
import { computed, ref, watch } from 'vue'
import { useGettext } from 'vue3-gettext'
import useSmartSearch from '~/composables/useSmartSearch'
import useOrdering from '~/composables/useOrdering'

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

// TODO (wvffle): Make sure everything is it's own type
const page = ref(1)
type ResponseType = { count: number, results: any[] }
const result = ref<null | ResponseType>(null)
const search = ref()

const { onSearch, query, addSearchToken, getTokenValue } = useSmartSearch(props.defaultQuery, props.updateUrl)
const { onOrderingUpdate, orderingString, paginateBy, ordering, orderingDirection } = useOrdering(props.orderingConfigName)

const orderingOptions: [OrderingField, keyof typeof sharedLabels.filters][] = [
  ['creation_date', 'creation_date'],
  ['name', 'name']
]

const actionFilters = computed(() => ({ q: query.value, ...props.filters }))
// TODO (wvffle): Find correct type
const actions: unknown[] = []

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
    const response = await axios.get('/manage/channels/', {
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
const { $pgettext } = useGettext()
const labels = computed(() => ({
  searchPlaceholder: $pgettext('Content/Search/Input.Placeholder', 'Search by domain, name, account…'),
  openModeration: $pgettext('Content/Moderation/Verb', 'Open in moderation interface')
}))
</script>

<template>
  <div>
    <div class="ui inline form">
      <div class="fields">
        <div class="ui six wide field">
          <label for="channel-search"><translate translate-context="Content/Search/Input.Label/Noun">Search</translate></label>
          <form @submit.prevent="query = search.value">
            <input
              id="channel-search"
              ref="search"
              name="search"
              type="text"
              :value="query"
              :placeholder="labels.searchPlaceholder"
            >
          </form>
        </div>
        <div class="field">
          <label for="channel-category"><translate translate-context="*/*/*">Category</translate></label>
          <select
            id="channel-category"
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
          <label for="channel-ordering"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering</translate></label>
          <select
            id="channel-ordering"
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
          <label for="channel-ordering-direction"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering direction</translate></label>
          <select
            id="channel-ordering-direction"
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
            <translate translate-context="*/*/*/Noun">
              Account
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
            <router-link :to="{name: 'manage.channels.detail', params: {id: scope.obj.actor.full_username }}">
              {{ scope.obj.artist.name }}
            </router-link>
          </td>
          <td>
            <router-link :to="{name: 'manage.moderation.accounts.detail', params: {id: scope.obj.attributed_to.full_username }}">
              <i class="wrench icon" />
              <span class="visually-hidden">{{ labels.openModeration }}</span>
            </router-link>
            <a
              href=""
              class="discrete link"
              @click.prevent="addSearchToken('account', scope.obj.attributed_to.full_username)"
            >{{ scope.obj.attributed_to.preferred_username }}</a>
          </td>
          <td>
            <template v-if="!scope.obj.is_local">
              <router-link :to="{name: 'manage.moderation.domains.detail', params: {id: scope.obj.attributed_to.domain }}">
                <i class="wrench icon" />
                <span class="visually-hidden">{{ labels.openModeration }}</span>
              </router-link>
              <a
                href=""
                class="discrete link"
                @click.prevent="addSearchToken('domain', scope.obj.attributed_to.domain)"
              >{{ scope.obj.attributed_to.domain }}</a>
            </template>
            <a
              v-else
              href=""
              class="ui tiny accent icon link label"
              @click.prevent="addSearchToken('domain', scope.obj.attributed_to.domain)"
            >
              <i class="home icon" />
              <translate translate-context="Content/Moderation/*/Short, Noun">Local</translate>
            </a>
          </td>
          <td>
            {{ scope.obj.artist.albums_count }}
          </td>
          <td>
            {{ scope.obj.artist.tracks_count }}
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
