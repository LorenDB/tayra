<script setup lang="ts">
import type { OrderingProps } from '~/composables/navigation/useOrdering'
import type { RouteRecordName } from 'vue-router'
import type { OrderingField } from '~/store/ui'

import { watchDebounced } from '@vueuse/core'
import { computed, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'

import axios from 'axios'

import ActionTable from '~/components/common/ActionTable.vue'
import Pagination from '~/components/vui/Pagination.vue'

import useSharedLabels from '~/composables/locale/useSharedLabels'
import useErrorHandler from '~/composables/useErrorHandler'
import useOrdering from '~/composables/navigation/useOrdering'

interface Props extends OrderingProps {
  filters?: object

  // TODO(wvffle): Remove after https://github.com/vuejs/core/pull/4512 is merged
  orderingConfigName?: RouteRecordName
}

const props = withDefaults(defineProps<Props>(), {
  filters: () => ({}),
  orderingConfigName: undefined
})

const page = ref(1)
const query = ref('')
type ResponseType = { count: number, results: any[] }
const result = ref<null | ResponseType>(null)

const { onOrderingUpdate, orderingString, paginateBy, ordering, orderingDirection } = useOrdering(props)

const orderingOptions: [OrderingField, keyof typeof sharedLabels.filters][] = [
  ['date_joined', 'date_joined'],
  ['last_activity', 'last_activity'],
  ['username', 'username']
]

const permissions = computed(() => [
  {
    code: 'library',
    label: t('components.manage.users.UsersTable.libraryLabel')
  },
  {
    code: 'moderation',
    label: t('components.manage.users.UsersTable.moderationLabel')
  },
  {
    code: 'settings',
    label: t('components.manage.users.UsersTable.settingsLabel')
  }
])

const { t } = useI18n()
const actionFilters = computed(() => ({ q: query.value, ...props.filters }))

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
    useErrorHandler(error as Error)
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
  searchPlaceholder: t('components.manage.users.UsersTable.searchPlaceholder')
}))
</script>

<template>
  <div>
    <div class="ui inline form">
      <div class="fields">
        <div class="ui field">
          <label for="users-search">{{ $t('components.manage.users.UsersTable.searchLabel') }}</label>
          <input
            id="users-search"
            v-model="query"
            name="search"
            type="text"
            :placeholder="labels.searchPlaceholder"
          >
        </div>
        <div class="field">
          <label for="users-ordering">{{ $t('components.manage.users.UsersTable.orderingLabel') }}</label>
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
          <label for="users-ordering-direction">{{ $t('components.manage.users.UsersTable.orderingDirectionLabel') }}</label>
          <select
            id="users-ordering-direction"
            v-model="orderingDirection"
            class="ui dropdown"
          >
            <option value="+">
              {{ $t('components.manage.users.UsersTable.ascendingOrdering') }}
            </option>
            <option value="-">
              {{ $t('components.manage.users.UsersTable.descendingOrdering') }}
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
        :actions="[]"
        :action-url="'manage/library/uploads/action/'"
        :filters="actionFilters"
        @action-launched="fetchData"
      >
        <template #header-cells>
          <th>
            {{ $t('components.manage.users.UsersTable.usernameTableHeader') }}
          </th>
          <th>
            {{ $t('components.manage.users.UsersTable.emailTableHeader') }}
          </th>
          <th>
            {{ $t('components.manage.users.UsersTable.accountStatusTableHeader') }}
          </th>
          <th>
            {{ $t('components.manage.users.UsersTable.signupTableHeader') }}
          </th>
          <th>
            {{ $t('components.manage.users.UsersTable.lastActivityTableHeader') }}
          </th>
          <th>
            {{ $t('components.manage.users.UsersTable.permissionsTableHeader') }}
          </th>
          <th>
            {{ $t('components.manage.users.UsersTable.statusTableHeader') }}
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
            >{{ $t('components.manage.users.UsersTable.activeStatus') }}</span>
            <span
              v-else
              class="ui basic label"
            >{{ $t('components.manage.users.UsersTable.inactiveStatus') }}</span>
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
              {{ $t('components.manage.users.UsersTable.notApplicable') }}
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
            >{{ $t('components.manage.users.UsersTable.adminPermission') }}</span>
            <span
              v-else-if="scope.obj.is_staff"
              class="ui purple label"
            >{{ $t('components.manage.users.UsersTable.staffPermission') }}</span>
            <span
              v-else
              class="ui basic label"
            >{{ $t('components.manage.users.UsersTable.regularPermission') }}</span>
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
        {{ $t('components.manage.users.UsersTable.resultsDisplay', {start: ((page-1) * paginateBy) + 1, end: ((page-1) * paginateBy) + result.results.length, total: result.count}) }}
      </span>
    </div>
  </div>
</template>
