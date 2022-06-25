<script setup lang="ts">
import axios from 'axios'
import moment from 'moment'
import Pagination from '~/components/vui/Pagination.vue'
import ActionTable from '~/components/common/ActionTable.vue'
import useSharedLabels from '~/composables/locale/useSharedLabels'
import { computed, ref, watch } from 'vue'
import { watchDebounced } from '@vueuse/core'
import { useGettext } from 'vue3-gettext'
import useOrdering, { OrderingProps } from '~/composables/useOrdering'
import { OrderingField } from '~/store/ui'

interface Props extends OrderingProps {
  // TODO (wvffle): find object type
  filters?: object
}

const props = withDefaults(defineProps<Props>(), {
  filters: () => ({})
})

// TODO (wvffle): Make sure everything is it's own type
const page = ref(1)
type ResponseType = { count: number, results: any[] }
const result = ref<null | ResponseType>(null)

const { onOrderingUpdate, orderingString, paginateBy, ordering } = useOrdering(props.orderingConfigName)

const orderingOptions: [OrderingField, keyof typeof sharedLabels.filters][] = [
  ['expiration_date', 'expiration_date'],
  ['creation_date', 'creation_date']
]

const query = ref('')
const isOpen = ref(false)
const { $pgettext } = useGettext()
const actionFilters = computed(() => ({ q: query.value, ...props.filters }))
const actions = [
  {
    name: 'delete',
    label: $pgettext('*/*/*/Verb', 'Delete'),
    filterCheckable: (obj: { users: unknown[], expiration_date: Date }) => {
      return obj.users.length === 0 && moment().isBefore(obj.expiration_date)
    }
  }
]

const isLoading = ref(false)
const fetchData = async () => {
  isLoading.value = true
  const params = {
    page: page.value,
    page_size: paginateBy.value,
    q: query.value,
    ordering: orderingString.value,
    is_open: isOpen.value,
    ...props.filters
  }

  try {
    const response = await axios.get('/manage/users/invitations/', {
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
watch(isOpen, () => (page.value = 1))
watch(page, fetchData)
onOrderingUpdate(fetchData)
fetchData()

const sharedLabels = useSharedLabels()
const labels = computed(() => ({
  searchPlaceholder: $pgettext('Content/Admin/Input.Placeholder/Verb', 'Search by username, e-mail address, code…')
}))
</script>

<template>
  <div>
    <div class="ui inline form">
      <div class="fields">
        <div class="ui field">
          <label for="invitations-search"><translate translate-context="Content/Search/Input.Label/Noun">Search</translate></label>
          <input
            id="invitations-search"
            v-model="query"
            name="search"
            type="text"
            :placeholder="labels.searchPlaceholder"
          >
        </div>
        <div class="field">
          <label for="invitations-ordering"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering</translate></label>
          <select
            id="invitations-ordering"
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
          <label for="invitations-status"><translate translate-context="*/*/*">Status</translate></label>
          <select
            id="invitations-status"
            v-model="isOpen"
            class="ui dropdown"
          >
            <option :value="null">
              <translate translate-context="Content/*/Dropdown">
                All
              </translate>
            </option>
            <option :value="true">
              <translate translate-context="Content/Admin/Dropdown/Adjective">
                Open
              </translate>
            </option>
            <option :value="false">
              <translate translate-context="Content/Admin/Dropdown/Adjective">
                Expired/used
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
        :action-url="'manage/users/invitations/action/'"
        :filters="actionFilters"
        @action-launched="fetchData"
      >
        <template #header-cells>
          <th>
            <translate translate-context="*/*/*">
              Owner
            </translate>
          </th>
          <th>
            <translate translate-context="*/*/*">
              Status
            </translate>
          </th>
          <th>
            <translate translate-context="Content/*/*/Noun">
              Creation date
            </translate>
          </th>
          <th>
            <translate translate-context="Content/Admin/Table.Label/Noun">
              Expiration date
            </translate>
          </th>
          <th>
            <translate translate-context="Content/Admin/Table.Label/Noun">
              Code
            </translate>
          </th>
        </template>
        <template
          #row-cells="scope"
        >
          <td>
            <router-link :to="{name: 'manage.users.users.detail', params: {id: scope.obj.id }}">
              {{ scope.obj.owner.username }}
            </router-link>
          </td>
          <td>
            <span
              v-if="scope.obj.users.length > 0"
              class="ui success basic label"
            ><translate translate-context="Content/Admin/Table">Used</translate></span>
            <span
              v-else-if="moment().isAfter(scope.obj.expiration_date)"
              class="ui danger basic label"
            ><translate translate-context="Content/Admin/Table">Expired</translate></span>
            <span
              v-else
              class="ui basic label"
            ><translate translate-context="Content/Admin/Table">Not used</translate></span>
          </td>
          <td>
            <human-date :date="scope.obj.creation_date" />
          </td>
          <td>
            <human-date :date="scope.obj.expiration_date" />
          </td>
          <td>
            {{ scope.obj.code.toUpperCase() }}
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
          translate-plural="Showing results %{ start } to %{ end } from %{ total }"
          :translate-params="{start: ((page-1) * paginateBy) + 1, end: ((page-1) * paginateBy) + result.results.length, total: result.count}"
          :translate-n="result.count"
        >
          Showing one result
        </translate>
      </span>
    </div>
  </div>
</template>
