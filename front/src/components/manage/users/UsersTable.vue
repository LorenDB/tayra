<script setup lang="ts">
import axios from 'axios'
import Pagination from '~/components/vui/Pagination.vue'
import ActionTable from '~/components/common/ActionTable.vue'
import useSharedLabels from '~/composables/locale/useSharedLabels'
import { computed, ref, watch } from 'vue'
import { watchDebounced } from '@vueuse/core'
import useOrdering, { OrderingProps } from '~/composables/useOrdering'
import { OrderingField } from '~/store/ui'
import { useGettext } from 'vue3-gettext'

interface Props extends OrderingProps {
  // TODO (wvffle): find object type
  filters?: object
}

const props = withDefaults(defineProps<Props>(), {
  filters: () => ({})
})

// TODO (wvffle): Make sure everything is it's own type
const page = ref(1)
const query = ref('')
type ResponseType = { count: number, results: any[] }
const result = ref<null | ResponseType>(null)

const { onOrderingUpdate, orderingString, paginateBy, ordering, orderingDirection } = useOrdering(props.orderingConfigName)

const orderingOptions: [OrderingField, keyof typeof sharedLabels.filters][] = [
  ['date_joined', 'date_joined'],
  ['last_activity', 'last_activity'],
  ['username', 'username']
]

const permissions = computed(() => [
  {
    code: 'library',
    label: $pgettext('*/*/*/Noun', 'Library')
  },
  {
    code: 'moderation',
    label: $pgettext('*/Moderation/*', 'Moderation')
  },
  {
    code: 'settings',
    label: $pgettext('*/*/*/Noun', 'Settings')
  }
])

const { $pgettext } = useGettext()
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
    const response = await axios.get('/manage/users/users/', {
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

watchDebounced(query, () => (page.value = 1), { debounce: 300 })
watch(page, fetchData)
onOrderingUpdate(fetchData)
fetchData()

const sharedLabels = useSharedLabels()
const labels = computed(() => ({
  searchPlaceholder: $pgettext('Content/Search/Input.Placeholder', 'Search by username, e-mail address, name…')
}))
</script>

<template>
  <div>
    <div class="ui inline form">
      <div class="fields">
        <div class="ui field">
          <label for="users-search"><translate translate-context="Content/Search/Input.Label/Noun">Search</translate></label>
          <input
            id="users-search"
            v-model="query"
            name="search"
            type="text"
            :placeholder="labels.searchPlaceholder"
          >
        </div>
        <div class="field">
          <label for="users-ordering"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering</translate></label>
          <select
            id="users-ordering"
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
          <label for="users-ordering-direction"><translate translate-context="Content/Search/Dropdown.Label/Noun">Order</translate></label>
          <select
            id="users-ordering-direction"
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
        :action-url="'manage/library/uploads/action/'"
        :filters="actionFilters"
        @action-launched="fetchData"
      >
        <template #header-cells>
          <th>
            <translate translate-context="Content/*/*">
              Username
            </translate>
          </th>
          <th>
            <translate translate-context="Content/*/*/Noun">
              Email
            </translate>
          </th>
          <th>
            <translate translate-context="Content/Admin/Table.Label/Short, Noun">
              Account status
            </translate>
          </th>
          <th>
            <translate translate-context="Content/Admin/Table.Label/Short, Noun (Value is a date)">
              Sign-up
            </translate>
          </th>
          <th>
            <translate translate-context="Content/Profile/Table.Label/Short, Noun (Value is a date)">
              Last activity
            </translate>
          </th>
          <th>
            <translate translate-context="Content/*/*/Noun">
              Permissions
            </translate>
          </th>
          <th>
            <translate translate-context="*/*/*">
              Status
            </translate>
          </th>
        </template>
        <template
          #row-cells="scope"
        >
          <td>
            <router-link
              v-if="scope.obj.actor"
              :to="{name: 'manage.moderation.accounts.detail', params: {id: scope.obj.actor.full_username }}"
            >
              {{ scope.obj.username }}
            </router-link>
            <router-link
              v-else
              :to="{name: 'manage.moderation.accounts.detail', params: {id: scope.obj.full_username }}"
            >
              {{ scope.obj.username }}
            </router-link>
          </td>
          <td>
            <span>{{ scope.obj.email }}</span>
          </td>
          <td>
            <span
              v-if="scope.obj.is_active"
              class="ui basic success label"
            ><translate translate-context="Content/Admin/Table">Active</translate></span>
            <span
              v-else
              class="ui basic label"
            ><translate translate-context="Content/Admin/Table">Inactive</translate></span>
          </td>
          <td>
            <human-date :date="scope.obj.date_joined" />
          </td>
          <td>
            <human-date
              v-if="scope.obj.last_activity"
              :date="scope.obj.last_activity"
            />
            <template v-else>
              <translate translate-context="*/*/*">
                N/A
              </translate>
            </template>
          </td>
          <td>
            <template
              v-for="p in permissions"
              :key="p.code"
            >
              <span
                v-if="scope.obj.permissions[p.code]"
                class="ui basic tiny label"
              >{{ p.label }}</span>
            </template>
          </td>
          <td>
            <span
              v-if="scope.obj.is_superuser"
              class="ui pink label"
            ><translate translate-context="Content/Admin/Table.User role">Admin</translate></span>
            <span
              v-else-if="scope.obj.is_staff"
              class="ui purple label"
            ><translate translate-context="Content/Profile/User role">Staff member</translate></span>
            <span
              v-else
              class="ui basic label"
            ><translate translate-context="Content/Admin/Table, User role">Regular user</translate></span>
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
