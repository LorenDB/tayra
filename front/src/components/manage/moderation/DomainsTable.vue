<script setup lang="ts">
import axios from 'axios'
import Pagination from '~/components/vui/Pagination.vue'
import ActionTable from '~/components/common/ActionTable.vue'
import useSharedLabels from '~/composables/locale/useSharedLabels'
import useOrdering, { OrderingProps } from '~/composables/useOrdering'
import { computed, ref, watch } from 'vue'
import { useGettext } from 'vue3-gettext'
import { OrderingField } from '~/store/ui'
import { watchDebounced } from '@vueuse/core'

interface Props extends OrderingProps {
  // TODO (wvffle): find object type
  filters?: object
  allowListEnabled?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  filters: () => ({}),
  allowListEnabled: false
})

// TODO (wvffle): Make sure everything is it's own type
const page = ref(1)
type ResponseType = { count: number, results: any[] }
const result = ref<null | ResponseType>(null)

const { onOrderingUpdate, orderingString, paginateBy, ordering, orderingDirection } = useOrdering(props.orderingConfigName)

const orderingOptions: [OrderingField, keyof typeof sharedLabels.filters][] = [
  ['name', 'name'],
  ['creation_date', 'first_seen'],
  ['actors_count', 'users'],
  ['outbox_activities_count', 'received_messages']
]

const { $pgettext } = useGettext()
const query = ref('')
const actionFilters = computed(() => ({ q: query.value, ...props.filters }))
const actions = [
  {
    name: 'purge',
    label: $pgettext('*/*/*/Verb', 'Purge'),
    isDangerous: true
  },
  {
    name: 'allow_list_add',
    label: $pgettext('Content/Moderation/Action/Verb', 'Add to allow-list'),
    filterCheckable: (obj: { allowed: boolean }) => {
      return !obj.allowed
    }
  },
  {
    name: 'allow_list_remove',
    label: $pgettext('Content/Moderation/Action/Verb', 'Remove from allow-list'),
    filterCheckable: (obj: { allowed: boolean }) => {
      return obj.allowed
    }
  }
]

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
  }

  if (params.allowed === null) {
    delete params.allowed
  }

  try {
    const response = await axios.get('/manage/federation/domains/', {
      params
      // TODO (wvffle): Check if params should be serialized. In other similar components (Podcasts, Artists) they are
      // paramsSerializer: function (params) {
      //   return qs.stringify(params, { indices: false })
      // }
    })

    result.value = response.data
  } catch (error) {
    // TODO (wvffle): Handle error
    result.value = null
  } finally {
    isLoading.value = false
  }
}

watchDebounced(query, () => (page.value = 1), { debounce: 300 })
watch(page, fetchData)
watch(allowed, fetchData)
onOrderingUpdate(fetchData)
fetchData()

const sharedLabels = useSharedLabels()
const labels = computed(() => ({
  searchPlaceholder: $pgettext('Content/Search/Input.Placeholder', 'Search by name…'),
  allowListTitle: $pgettext('Content/Moderation/Popup', 'This domain is present in your allow-list')
}))
</script>

<template>
  <div>
    <div class="ui inline form">
      <div class="fields">
        <div class="ui field">
          <label for="domains-search"><translate translate-context="Content/Search/Input.Label/Noun">Search</translate></label>
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
          <label for="domains-allow-list"><translate translate-context="Content/Moderation/*/Adjective">Is present on allow-list</translate></label>
          <select
            id="domains-allow-list"
            v-model="allowed"
            class="ui dropdown"
          >
            <option :value="null">
              <translate translate-context="Content/*/Dropdown">
                All
              </translate>
            </option>
            <option :value="true">
              <translate translate-context="*/*/*">
                Yes
              </translate>
            </option>
            <option :value="false">
              <translate translate-context="*/*/*">
                No
              </translate>
            </option>
          </select>
        </div>
        <div class="field">
          <label for="domains-ordering"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering</translate></label>
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
          <label for="domains-ordering-direction"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering direction</translate></label>
          <select
            id="domains-ordering-direction"
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
            <translate translate-context="*/*/*/Noun">
              Name
            </translate>
          </th>
          <th>
            <translate translate-context="*/*/*/Noun">
              Users
            </translate>
          </th>
          <th>
            <translate translate-context="Content/Moderation/*/Noun">
              Received messages
            </translate>
          </th>
          <th>
            <translate translate-context="Content/Moderation/Table.Label/Short (Value is a date)">
              First seen
            </translate>
          </th>
          <th>
            <translate translate-context="Content/Moderation/Table.Label/Short">
              Under moderation rule
            </translate>
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
            <span v-if="scope.obj.instance_policy"><i class="shield icon" /> <translate translate-context="*/*/*">Yes</translate></span>
          </td>
        </template>
      </action-table>
      <div
        v-else
        class="ui placeholder segment"
      >
        <div class="ui icon header">
          <i class="server icon" />
          <translate translate-context="Content/Home/Placeholder">
            No other pods found
          </translate>
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
