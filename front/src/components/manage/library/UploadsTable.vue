<script setup lang="ts">
import type { RouteWithPreferences, OrderingField } from '~/store/ui'
import type { SmartSearchProps } from '~/composables/useSmartSearch'
import type { ImportStatus, PrivacyLevel, Upload } from '~/types'
import type { OrderingProps } from '~/composables/useOrdering'

import { humanSize, truncate } from '~/utils/filters'
import { ref, computed, watch } from 'vue'
import { useGettext } from 'vue3-gettext'

import axios from 'axios'

import ImportStatusModal from '~/components/library/ImportStatusModal.vue'
import ActionTable from '~/components/common/ActionTable.vue'
import Pagination from '~/components/vui/Pagination.vue'

import useSharedLabels from '~/composables/locale/useSharedLabels'
import useErrorHandler from '~/composables/useErrorHandler'
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

const search = ref()

// TODO (wvffle): Make sure everything is it's own type
const page = ref(1)
type ResponseType = { count: number, results: any[] }
const result = ref<null | ResponseType>(null)

const { onSearch, query, addSearchToken, getTokenValue } = useSmartSearch(props.defaultQuery, props.updateUrl)
const { onOrderingUpdate, orderingString, paginateBy, ordering, orderingDirection } = useOrdering(props.orderingConfigName)

const orderingOptions: [OrderingField, keyof typeof sharedLabels.filters][] = [
  ['creation_date', 'creation_date'],
  ['modification_date', 'modification_date'],
  ['accessed_date', 'accessed_date'],
  ['size', 'size'],
  ['bitrate', 'bitrate'],
  ['duration', 'duration']
]

const { $pgettext } = useGettext()
const actionFilters = computed(() => ({ q: query.value, ...props.filters }))
const actions = computed(() => [
  {
    name: 'delete',
    label: $pgettext('*/*/*/Verb', 'Delete'),
    confirmationMessage: $pgettext('Popup/*/Paragraph', 'The selected upload will be removed. This action is irreversible.'),
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
  searchPlaceholder: $pgettext('Content/Search/Input.Placeholder', 'Search by domain, actor, name, reference, source…')
}))

const displayName = (upload: Upload): string => {
  return upload.filename ?? upload.source ?? upload.uuid
}

const detailedUpload = ref({})
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
          <label for="uploads-search"><translate translate-context="Content/Search/Input.Label/Noun">Search</translate></label>
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
          <label for="uploads-visibility"><translate translate-context="*/*/*">Visibility</translate></label>
          <select
            id="uploads-visibility"
            class="ui dropdown"
            :value="getTokenValue('privacy_level', '')"
            @change="addSearchToken('privacy_level', ($event.target as HTMLSelectElement).value)"
          >
            <option value="">
              <translate translate-context="Content/*/Dropdown">
                All
              </translate>
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
          <label for="uploads-status"><translate translate-context="Content/*/*/Noun">Import status</translate></label>
          <select
            id="uploads-status"
            class="ui dropdown"
            :value="getTokenValue('status', '')"
            @change="addSearchToken('status', ($event.target as HTMLSelectElement).value)"
          >
            <option value="">
              <translate translate-context="Content/*/Dropdown">
                All
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
          <label for="uploads-ordering"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering</translate></label>
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
          <label for="uploads-ordering-direction"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering direction</translate></label>
          <select
            id="uploads-ordering-direction"
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
    <!-- TODO (wvffle): Check if :upload shouldn't be v-modl:upload -->
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
        action-url="manage/library/uploads/action/"
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
              Library
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
              Visibility
            </translate>
          </th>
          <th>
            <translate translate-context="Content/*/*/Noun">
              Import status
            </translate>
          </th>
          <th>
            <translate translate-context="Content/*/*/Noun">
              Size
            </translate>
          </th>
          <th>
            <translate translate-context="Content/*/*/Noun">
              Creation date
            </translate>
          </th>
          <th>
            <translate translate-context="Content/*/*/Noun">
              Accessed date
            </translate>
          </th>
        </template>
        <template
          #row-cells="scope"
        >
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
              <translate translate-context="Content/Moderation/*/Short, Noun">Local</translate>
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
              :title="sharedLabels.fields.import_status.detailTitle"
              @click="detailedUpload = scope.obj; showUploadDetailModal = true"
            >
              <i class="question circle outline icon" />
            </button>
          </td>
          <td>
            <span v-if="scope.obj.size">{{ humanSize(scope.obj.size) }}</span>
            <translate
              v-else
              translate-context="*/*/*"
            >
              N/A
            </translate>
          </td>
          <td>
            <human-date :date="scope.obj.creation_date" />
          </td>
          <td>
            <human-date
              v-if="scope.obj.accessed_date"
              :date="scope.obj.accessed_date"
            />
            <translate
              v-else
              translate-context="*/*/*"
            >
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
        >
          Showing results %{ start }-%{ end } on %{ total }
        </translate>
      </span>
    </div>
  </div>
</template>
