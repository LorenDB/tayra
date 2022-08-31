<script setup lang="ts">
import type { RouteWithPreferences, OrderingField } from '~/store/ui'
import type { SmartSearchProps } from '~/composables/useSmartSearch'
import type { OrderingProps } from '~/composables/useOrdering'
import type { ImportStatus } from '~/types'

import { humanSize, truncate } from '~/utils/filters'
import { computed, ref, watch } from 'vue'
import { useGettext } from 'vue3-gettext'

import time from '~/utils/time'
import axios from 'axios'

import ImportStatusModal from '~/components/library/ImportStatusModal.vue'
import ActionTable from '~/components/common/ActionTable.vue'
import Pagination from '~/components/vui/Pagination.vue'

import useSharedLabels from '~/composables/locale/useSharedLabels'
import useErrorHandler from '~/composables/useErrorHandler'
import useSmartSearch from '~/composables/useSmartSearch'
import useOrdering from '~/composables/useOrdering'

interface Events {
  (e: 'fetch-start'): void
}

interface Props extends SmartSearchProps, OrderingProps {
  filters?: object
  needsRefresh?: boolean
  customObjects?: any[]

  // TODO(wvffle): Remove after https://github.com/vuejs/core/pull/4512 is merged
  orderingConfigName: RouteWithPreferences | null
  defaultQuery?: string
  updateUrl?: boolean
}

const emit = defineEmits<Events>()
const props = withDefaults(defineProps<Props>(), {
  defaultQuery: '',
  updateUrl: false,
  filters: () => ({}),
  needsRefresh: false,
  customObjects: () => []
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
  ['title', 'track_title'],
  ['size', 'size'],
  ['duration', 'duration'],
  ['bitrate', 'bitrate'],
  ['album_title', 'album_title'],
  ['artist_name', 'artist_name']
]

const { $pgettext } = useGettext()
const actionFilters = computed(() => ({ q: query.value, ...props.filters }))
const actions = computed(() => [
  {
    name: 'delete',
    label: $pgettext('*/*/*/Verb', 'Delete'),
    isDangerous: true,
    allowAll: true,
    confirmColor: 'danger'
  },
  {
    name: 'relaunch_import',
    label: $pgettext('Content/Library/Dropdown/Verb', 'Restart import'),
    isDangerous: true,
    allowAll: true,
    // TODO (wvffle): Find correct type
    filterCheckable: (filter: { import_status: string }) => {
      return filter.import_status !== 'finished'
    }
  }
])

const isLoading = ref(false)
const fetchData = async () => {
  emit('fetch-start')
  isLoading.value = true
  const params = {
    page: page.value,
    page_size: paginateBy.value,
    q: query.value,
    ordering: orderingString.value,
    include_channels: 'true',
    ...props.filters
  }

  try {
    const response = await axios.get('/uploads/', {
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
onOrderingUpdate(() => (page.value = 1))
watch(page, fetchData)
fetchData()

const sharedLabels = useSharedLabels()
const labels = computed(() => ({
  searchPlaceholder: $pgettext('Content/Library/Input.Placeholder', 'Search by title, artist, album…'),
  showStatus: $pgettext('Content/Library/Button.Label/Verb', 'Show information about the upload status for this track')
}))

const detailedUpload = ref()
const showUploadDetailModal = ref(false)

const getImportStatusChoice = (importStatus: ImportStatus) => {
  return sharedLabels.fields.import_status.choices[importStatus]
}
</script>

<template>
  <div>
    <div class="ui inline form">
      <div class="fields">
        <div class="ui six wide field">
          <label for="files-search">
            <translate translate-context="Content/Search/Input.Label/Noun">Search</translate>
          </label>
          <form @submit.prevent="query = search.value">
            <input
              id="files-search"
              ref="search"
              name="search"
              type="text"
              :value="query"
              :placeholder="labels.searchPlaceholder"
            >
          </form>
        </div>
        <div class="field">
          <label for="import-status">
            <translate translate-context="Content/*/*/Noun">Import status</translate>
          </label>
          <select
            id="import-status"
            class="ui dropdown"
            :value="getTokenValue('status', '')"
            @change="addSearchToken('status', ($event.target as HTMLSelectElement).value)"
          >
            <option value>
              <translate translate-context="Content/*/Dropdown">
                All
              </translate>
            </option>
            <option value="draft">
              <translate translate-context="Content/Library/*/Short">
                Draft
              </translate>
            </option>
            <option value="pending">
              <translate translate-context="Content/Library/*/Short">
                Pending
              </translate>
            </option>
            <option value="skipped">
              <translate translate-context="Content/Library/*">
                Skipped
              </translate>
            </option>
            <option value="errored">
              <translate translate-context="Content/Library/Dropdown">
                Failed
              </translate>
            </option>
            <option value="finished">
              <translate translate-context="Content/Library/*">
                Finished
              </translate>
            </option>
          </select>
        </div>
        <div class="field">
          <label for="ordering-select">
            <translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering</translate>
          </label>
          <select
            id="ordering-select"
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
          <label for="ordering-direction">
            <translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering direction</translate>
          </label>
          <select
            id="ordering-direction"
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
      v-if="detailedUpload"
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
      <div
        v-else-if="!result || result?.results.length === 0 && !needsRefresh"
        class="ui placeholder segment"
      >
        <div class="ui icon header">
          <i class="upload icon" />
          <translate
            translate-context="Content/Home/Placeholder"
          >
            No tracks have been added to this library yet
          </translate>
        </div>
      </div>
      <action-table
        v-else
        :id-field="'uuid'"
        :objects-data="result"
        :custom-objects="customObjects"
        :actions="actions"
        :refreshable="true"
        :needs-refresh="needsRefresh"
        :action-url="'uploads/action/'"
        :filters="actionFilters"
        @action-launched="fetchData"
        @refresh="fetchData"
      >
        <template #header-cells>
          <th>
            <translate translate-context="*/*/*/Noun">
              Title
            </translate>
          </th>
          <th>
            <translate translate-context="*/*/*/Noun">
              Artist
            </translate>
          </th>
          <th>
            <translate translate-context="*/*/*">
              Album
            </translate>
          </th>
          <th>
            <translate translate-context="*/*/*/Noun">
              Upload date
            </translate>
          </th>
          <th>
            <translate translate-context="Content/*/*/Noun">
              Import status
            </translate>
          </th>
          <th>
            <translate translate-context="Content/*/*">
              Duration
            </translate>
          </th>
          <th>
            <translate translate-context="Content/*/*/Noun">
              Size
            </translate>
          </th>
        </template>
        <template
          #row-cells="scope"
        >
          <template v-if="scope.obj.track">
            <td>
              <router-link :to="{name: 'library.tracks.detail', params: {id: scope.obj.track.id }}">
                {{ truncate(scope.obj.track.title, 25) }}
              </router-link>
            </td>
            <td>
              <a
                href=""
                class="discrete link"
                @click.prevent="addSearchToken('artist', scope.obj.track.artist.name)"
              >{{ truncate(scope.obj.track.artist.name, 20) }}</a>
            </td>
            <td>
              <a
                v-if="scope.obj.track.album"
                href=""
                class="discrete link"
                @click.prevent="addSearchToken('album', scope.obj.track.album.title)"
              >{{ truncate(scope.obj.track.album.title, 20) }}</a>
            </td>
          </template>
          <template v-else>
            <td :title="scope.obj.source">
              {{ truncate(scope.obj.source, 25) }}
            </td>
            <td />
            <td />
          </template>
          <td>
            <human-date :date="scope.obj.creation_date" />
          </td>
          <td>
            <a
              href=""
              class="discrete link"
              :title="getImportStatusChoice(scope.obj.import_status).help"
              @click.prevent="addSearchToken('status', scope.obj.import_status)"
            >{{ getImportStatusChoice(scope.obj.import_status).label }}</a>
            <button
              class="ui tiny basic icon button"
              :title="sharedLabels.fields.import_status.label"
              :aria-label="labels.showStatus"
              @click="detailedUpload = scope.obj; showUploadDetailModal = true"
            >
              <i class="question circle outline icon" />
            </button>
          </td>
          <td v-if="scope.obj.duration">
            {{ time.parse(scope.obj.duration) }}
          </td>
          <td v-else>
            <translate translate-context="*/*/*">
              N/A
            </translate>
          </td>
          <td v-if="scope.obj.size">
            {{ humanSize(scope.obj.size) }}
          </td>
          <td v-else>
            <translate translate-context="*/*/*">
              N/A
            </translate>
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
        >Showing results %{ start }-%{ end } on %{ total }</translate>
      </span>
    </div>
  </div>
</template>
