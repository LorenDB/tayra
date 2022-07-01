<script setup lang="ts">
import axios from 'axios'
import Pagination from '~/components/vui/Pagination.vue'
import ActionTable from '~/components/common/ActionTable.vue'
import ImportStatusModal from '~/components/library/ImportStatusModal.vue'
import { truncate } from '~/utils/filters'
import useSharedLabels from '~/composables/locale/useSharedLabels'
import useSmartSearch, { SmartSearchProps } from '~/composables/useSmartSearch'
import useOrdering, { OrderingProps } from '~/composables/useOrdering'
import { OrderingField } from '~/store/ui'
import { computed, ref, watch } from 'vue'
import { useGettext } from 'vue3-gettext'

interface Props extends SmartSearchProps, OrderingProps {
  // TODO (wvffle): find object type
  filters?: object
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

const { onSearch, query } = useSmartSearch(props.defaultQuery, props.updateUrl)
const { onOrderingUpdate, orderingString, paginateBy, ordering, orderingDirection } = useOrdering(props.orderingConfigName)

const orderingOptions: [OrderingField, keyof typeof sharedLabels.filters][] = [
  ['creation_date', 'creation_date'],
  ['name', 'name'],
  ['length', 'length'],
  ['items_count', 'items_count']
]

const { $pgettext } = useGettext()
const actionFilters = computed(() => ({ q: query.value, ...props.filters }))
const actions = computed(() => [
  {
    name: 'delete',
    label: $pgettext('*/*/*/Verb', 'Delete'),
    confirmationMessage: $pgettext('Popup/*/Paragraph', 'The selected tag will be removed and unlinked with existing content, if any. This action is irreversible.'),
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
    const response = await axios.get('/manage/tags/', {
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
  searchPlaceholder: $pgettext('Content/Search/Input.Placeholder', 'Search by name')
}))

// TODO (wvffle): Check if we can remove the prop
const detailedUpload = ref({})
const showUploadDetailModal = ref(false)
</script>

<template>
  <div>
    <div class="ui inline form">
      <div class="fields">
        <div class="ui six wide field">
          <label for="tags-search"><translate translate-context="Content/Search/Input.Label/Noun">Search</translate></label>
          <form @submit.prevent="query = $refs.search.value">
            <input
              id="tags-search"
              ref="search"
              name="search"
              type="text"
              :value="query"
              :placeholder="labels.searchPlaceholder"
            >
          </form>
        </div>
        <div class="field">
          <label for="tags-ordering"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering</translate></label>
          <select
            id="tags-ordering"
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
          <label for="tags-ordering-direction"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering direction</translate></label>
          <select
            id="tags-ordering-direction"
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
    <import-status-modal
      v-model:show="showUploadDetailModal"
      :upload="detailedUpload"
    />
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
        action-url="manage/tags/action/"
        id-field="name"
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
              Artists
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
            <router-link :to="{name: 'manage.library.tags.detail', params: {id: scope.obj.name }}">
              {{ truncate(scope.obj.name, 30, undefined, true) }}
            </router-link>
          </td>
          <td>
            {{ scope.obj.artists_count }}
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
