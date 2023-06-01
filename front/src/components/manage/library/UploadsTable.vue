<script setup lang="ts">
import type { ImportStatus, PrivacyLevel, Upload, BackendResponse } from '~/types'
import type { SmartSearchProps } from '~/composables/navigation/useSmartSearch'
import type { OrderingProps } from '~/composables/navigation/useOrdering'
import type { RouteRecordName } from 'vue-router'
import type { OrderingField } from '~/store/ui'

import { humanSize, truncate } from '~/utils/filters'
import { ref, computed, watch } from 'vue'
import { useI18n } from 'vue-i18n'

import axios from 'axios'

import ImportStatusModal from '~/components/library/ImportStatusModal.vue'
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
const result = ref<BackendResponse<Upload>>()

const { onSearch, query, addSearchToken, getTokenValue } = useSmartSearch(props)
const { onOrderingUpdate, orderingString, paginateBy, ordering, orderingDirection } = useOrdering(props)

const orderingOptions: [OrderingField, keyof typeof sharedLabels.filters][] = [
  ['creation_date', 'creation_date'],
  ['modification_date', 'modification_date'],
  ['accessed_date', 'accessed_date'],
  ['size', 'size'],
  ['bitrate', 'bitrate'],
  ['duration', 'duration']
]

const { t } = useI18n()
const actionFilters = computed(() => ({ q: query.value, ...props.filters }))
const actions = computed(() => [
  {
    name: 'delete',
    label: t('components.manage.library.UploadsTable.action.delete.label'),
    confirmationMessage: t('components.manage.library.UploadsTable.action.delete.warning'),
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
    const response = await axios.get('/manage/library/uploads/', {
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
watch(page, fetchData)
onOrderingUpdate(fetchData)
fetchData()

const sharedLabels = useSharedLabels()
const labels = computed(() => ({
  searchPlaceholder: t('components.manage.library.UploadsTable.placeholder.search')
}))

const displayName = (upload: Upload): string => {
  return upload.filename ?? upload.source ?? upload.uuid
}

const detailedUpload = ref<Upload>()
const showUploadDetailModal = ref(false)

const getImportStatusChoice = (importStatus: ImportStatus) => {
  return sharedLabels.fields.import_status.choices[importStatus]
}

const getPrivacyLevelChoice = (privacyLevel: PrivacyLevel) => {
  return sharedLabels.fields.privacy_level.shortChoices[privacyLevel]
}
</script>

<template>
  <div>
    <div class="ui inline form">
      <div class="fields">
        <div class="ui six wide field">
          <label for="uploads-search">{{ $t('components.manage.library.UploadsTable.label.search') }}</label>
          <form @submit.prevent="query = search.value">
            <input
              id="uploads-search"
              ref="search"
              name="search"
              type="text"
              :value="query"
              :placeholder="labels.searchPlaceholder"
            >
          </form>
        </div>
        <div class="field">
          <label for="uploads-visibility">{{ $t('components.manage.library.UploadsTable.label.visibility') }}</label>
          <select
            id="uploads-visibility"
            class="ui dropdown"
            :value="getTokenValue('privacy_level', '')"
            @change="addSearchToken('privacy_level', ($event.target as HTMLSelectElement).value)"
          >
            <option value="">
              {{ $t('components.manage.library.UploadsTable.option.all') }}
            </option>
            <option value="me">
              {{ sharedLabels.fields.privacy_level.shortChoices.me }}
            </option>
            <option value="instance">
              {{ sharedLabels.fields.privacy_level.shortChoices.instance }}
            </option>
            <option value="everyone">
              {{ sharedLabels.fields.privacy_level.shortChoices.everyone }}
            </option>
          </select>
        </div>
        <div class="field">
          <label for="uploads-status">{{ $t('components.manage.library.UploadsTable.label.status') }}</label>
          <select
            id="uploads-status"
            class="ui dropdown"
            :value="getTokenValue('status', '')"
            @change="addSearchToken('status', ($event.target as HTMLSelectElement).value)"
          >
            <option value="">
              {{ $t('components.manage.library.UploadsTable.option.all') }}
            </option>
            <option value="pending">
              {{ $t('components.manage.library.UploadsTable.option.pending') }}
            </option>
            <option value="skipped">
              {{ $t('components.manage.library.UploadsTable.option.skipped') }}
            </option>
            <option value="errored">
              {{ $t('components.manage.library.UploadsTable.option.failed') }}
            </option>
            <option value="finished">
              {{ $t('components.manage.library.UploadsTable.option.finished') }}
            </option>
          </select>
        </div>
        <div class="field">
          <label for="uploads-ordering">{{ $t('components.manage.library.UploadsTable.ordering.label') }}</label>
          <select
            id="uploads-ordering"
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
          <label for="uploads-ordering-direction">{{ $t('components.manage.library.UploadsTable.ordering.direction.label') }}</label>
          <select
            id="uploads-ordering-direction"
            v-model="orderingDirection"
            class="ui dropdown"
          >
            <option value="+">
              {{ $t('components.manage.library.UploadsTable.ordering.direction.ascending') }}
            </option>
            <option value="-">
              {{ $t('components.manage.library.UploadsTable.ordering.direction.descending') }}
            </option>
          </select>
        </div>
      </div>
    </div>
    <!-- TODO (wvffle): Check if :upload shouldn't be v-model:upload -->
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
      <action-table
        v-if="result"
        :objects-data="result"
        :actions="actions"
        action-url="manage/library/uploads/action/"
        :filters="actionFilters"
        @action-launched="fetchData"
      >
        <template #header-cells>
          <th>
            {{ $t('components.manage.library.UploadsTable.table.upload.header.name') }}
          </th>
          <th>
            {{ $t('components.manage.library.UploadsTable.table.upload.header.library') }}
          </th>
          <th>
            {{ $t('components.manage.library.UploadsTable.table.upload.header.account') }}
          </th>
          <th>
            {{ $t('components.manage.library.UploadsTable.table.upload.header.domain') }}
          </th>
          <th>
            {{ $t('components.manage.library.UploadsTable.table.upload.header.visibility') }}
          </th>
          <th>
            {{ $t('components.manage.library.UploadsTable.table.upload.header.importStatus') }}
          </th>
          <th>
            {{ $t('components.manage.library.UploadsTable.table.upload.header.size') }}
          </th>
          <th>
            {{ $t('components.manage.library.UploadsTable.table.upload.header.creationDate') }}
          </th>
          <th>
            {{ $t('components.manage.library.UploadsTable.table.upload.header.accessedDate') }}
          </th>
        </template>
        <template #row-cells="scope">
          <td>
            <router-link :to="{name: 'manage.library.uploads.detail', params: {id: scope.obj.uuid }}">
              {{ truncate(displayName(scope.obj), 30, undefined, true) }}
            </router-link>
          </td>
          <td>
            <router-link :to="{name: 'manage.library.libraries.detail', params: {id: scope.obj.library.uuid }}">
              <i class="wrench icon" />
            </router-link>
            <a
              href=""
              class="discrete link"
              :title="scope.obj.library.name"
              @click.prevent="addSearchToken('library_id', scope.obj.library.id)"
            >
              {{ truncate(scope.obj.library.name, 20) }}
            </a>
          </td>
          <td>
            <router-link :to="{name: 'manage.moderation.accounts.detail', params: {id: scope.obj.library.actor.full_username }}" />
            <a
              href=""
              class="discrete link"
              :title="scope.obj.library.actor.full_username"
              @click.prevent="addSearchToken('account', scope.obj.library.actor.full_username)"
            >{{ scope.obj.library.actor.preferred_username }}</a>
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
              {{ $t('components.manage.library.UploadsTable.link.local') }}
            </a>
          </td>
          <td>
            <a
              href=""
              class="discrete link"
              :title="getPrivacyLevelChoice(scope.obj.library.privacy_level)"
              @click.prevent="addSearchToken('privacy_level', scope.obj.library.privacy_level)"
            >
              {{ getPrivacyLevelChoice(scope.obj.library.privacy_level) }}
            </a>
          </td>
          <td>
            <a
              href=""
              class="discrete link"
              :title="getImportStatusChoice(scope.obj.import_status).help"
              @click.prevent="addSearchToken('status', scope.obj.import_status)"
            >
              {{ getImportStatusChoice(scope.obj.import_status).label }}
            </a>
            <button
              class="ui tiny basic icon button"
              :title="sharedLabels.fields.import_status.label"
              @click="detailedUpload = scope.obj; showUploadDetailModal = true"
            >
              <i class="question circle outline icon" />
            </button>
          </td>
          <td>
            <span v-if="scope.obj.size">{{ humanSize(scope.obj.size) }}</span>
            <span v-else>
              {{ $t('components.manage.library.UploadsTable.notApplicable') }}
            </span>
          </td>
          <td>
            <human-date :date="scope.obj.creation_date" />
          </td>
          <td>
            <human-date
              v-if="scope.obj.accessed_date"
              :date="scope.obj.accessed_date"
            />
            <span v-else>
              {{ $t('components.manage.library.UploadsTable.notApplicable') }}
            </span>
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
        {{ $t('components.manage.library.UploadsTable.pagination.results', {start: ((page-1) * paginateBy) + 1, end: ((page-1) * paginateBy) + result.results.length, total: result.count}) }}
      </span>
    </div>
  </div>
</template>
