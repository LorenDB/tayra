<script setup lang="ts">
import type { SmartSearchProps } from '~/composables/navigation/useSmartSearch'
import type { OrderingProps } from '~/composables/navigation/useOrdering'
import type { ImportStatus, BackendResponse, Upload } from '~/types'
import type { RouteRecordName } from 'vue-router'
import type { OrderingField } from '~/store/ui'

import { humanSize, truncate } from '~/utils/filters'
import { computed, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'

import time from '~/utils/time'
import axios from 'axios'

import ImportStatusModal from '~/components/library/ImportStatusModal.vue'
import ActionTable from '~/components/common/ActionTable.vue'
import Pagination from '~/components/vui/Pagination.vue'

import useSharedLabels from '~/composables/locale/useSharedLabels'
import useSmartSearch from '~/composables/navigation/useSmartSearch'
import useOrdering from '~/composables/navigation/useOrdering'
import useErrorHandler from '~/composables/useErrorHandler'
import usePage from '~/composables/navigation/usePage'

interface Events {
  (e: 'fetch-start'): void
}

interface Props extends SmartSearchProps, OrderingProps {
  filters?: object
  needsRefresh?: boolean
  customObjects?: any[]

  // TODO(wvffle): Remove after https://github.com/vuejs/core/pull/4512 is merged
  orderingConfigName?: RouteRecordName
  defaultQuery?: string
  updateUrl?: boolean
}

const emit = defineEmits<Events>()
const props = withDefaults(defineProps<Props>(), {
  defaultQuery: '',
  updateUrl: false,
  filters: () => ({}),
  needsRefresh: false,
  customObjects: () => [],
  orderingConfigName: undefined
})

const search = ref()

const page = usePage()
const result = ref<BackendResponse<Upload>>()

const { onSearch, query, addSearchToken, getTokenValue } = useSmartSearch(props)
const { onOrderingUpdate, orderingString, paginateBy, ordering, orderingDirection } = useOrdering(props)

const orderingOptions: [OrderingField, keyof typeof sharedLabels.filters][] = [
  ['creation_date', 'creation_date'],
  ['title', 'track_title'],
  ['size', 'size'],
  ['duration', 'duration'],
  ['bitrate', 'bitrate'],
  ['album_title', 'album_title'],
  ['artist_name', 'artist_name']
]

const { t } = useI18n()
const actionFilters = computed(() => ({ q: query.value, ...props.filters }))
const actions = computed(() => [
  {
    name: 'delete',
    label: t('views.content.libraries.FilesTable.action.delete'),
    isDangerous: true,
    allowAll: true,
    confirmColor: 'danger'
  },
  {
    name: 'relaunch_import',
    label: t('views.content.libraries.FilesTable.action.restartImport'),
    isDangerous: true,
    allowAll: true,
    filterCheckable: (filter: { import_status: ImportStatus }) => {
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
    result.value = undefined
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
  searchPlaceholder: t('views.content.libraries.FilesTable.placeholder.search'),
  showStatus: t('views.content.libraries.FilesTable.button.showStatus')
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
            {{ $t('views.content.libraries.FilesTable.label.search') }}
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
            {{ $t('views.content.libraries.FilesTable.label.importStatus') }}
          </label>
          <select
            id="import-status"
            class="ui dropdown"
            :value="getTokenValue('status', '')"
            @change="addSearchToken('status', ($event.target as HTMLSelectElement).value)"
          >
            <option value>
              {{ $t('views.content.libraries.FilesTable.option.status.all') }}
            </option>
            <option value="draft">
              {{ $t('views.content.libraries.FilesTable.option.status.draft') }}
            </option>
            <option value="pending">
              {{ $t('views.content.libraries.FilesTable.option.status.pending') }}
            </option>
            <option value="skipped">
              {{ $t('views.content.libraries.FilesTable.option.status.skipped') }}
            </option>
            <option value="errored">
              {{ $t('views.content.libraries.FilesTable.option.status.failed') }}
            </option>
            <option value="finished">
              {{ $t('views.content.libraries.FilesTable.option.status.finished') }}
            </option>
          </select>
        </div>
        <div class="field">
          <label for="ordering-select">
            {{ $t('views.content.libraries.FilesTable.ordering.label') }}
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
            {{ $t('views.content.libraries.FilesTable.ordering.direction.label') }}
          </label>
          <select
            id="ordering-direction"
            v-model="orderingDirection"
            class="ui dropdown"
          >
            <option value="+">
              {{ $t('views.content.libraries.FilesTable.ordering.direction.ascending') }}
            </option>
            <option value="-">
              {{ $t('views.content.libraries.FilesTable.ordering.direction.descending') }}
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
          {{ $t('views.content.libraries.FilesTable.empty.noTracks') }}
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
            {{ $t('views.content.libraries.FilesTable.table.file.header.title') }}
          </th>
          <th>
            {{ $t('views.content.libraries.FilesTable.table.file.header.artist') }}
          </th>
          <th>
            {{ $t('views.content.libraries.FilesTable.table.file.header.album') }}
          </th>
          <th>
            {{ $t('views.content.libraries.FilesTable.table.file.header.uploadDate') }}
          </th>
          <th>
            {{ $t('views.content.libraries.FilesTable.table.file.header.importStatus') }}
          </th>
          <th>
            {{ $t('views.content.libraries.FilesTable.table.file.header.duration') }}
          </th>
          <th>
            {{ $t('views.content.libraries.FilesTable.table.file.header.size') }}
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
            {{ $t('views.content.libraries.FilesTable.notApplicable') }}
          </td>
          <td v-if="scope.obj.size">
            {{ humanSize(scope.obj.size) }}
          </td>
          <td v-else>
            {{ $t('views.content.libraries.FilesTable.notApplicable') }}
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
        {{ $t('views.content.libraries.FilesTable.pagination.results', {start: ((page-1) * paginateBy) + 1, end: ((page-1) * paginateBy) + result.results.length, total: result.count}) }}
      </span>
    </div>
  </div>
</template>
