<template>
  <div>
    <div class="ui inline form">
      <div class="fields">
        <div class="ui field">
          <label for="users-search"><translate translate-context="Content/Search/Input.Label/Noun">Search</translate></label>
          <input
            id="users-search"
            v-model="search"
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
              v-for="(p, key) in permissions"
            >
              <span
                v-if="scope.obj.permissions[p.code]"
                :key="key"
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
        :compact="true"
        :current="page"
        :paginate-by="paginateBy"
        :total="result.count"
        @page-changed="selectPage"
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

<script>
import axios from 'axios'
import { merge } from 'lodash-es'
import time from '~/utils/time'
import Pagination from '~/components/Pagination.vue'
import ActionTable from '~/components/common/ActionTable.vue'
import OrderingMixin from '~/components/mixins/Ordering.vue'
import useSharedLabels from '../../../composables/useSharedLabels'

export default {
  components: {
    Pagination,
    ActionTable
  },
  mixins: [OrderingMixin],
  props: {
    filters: { type: Object, required: false, default: function () { return {} } }
  },
  setup () {
    const sharedLabels = useSharedLabels()
    return { sharedLabels }
  },
  data () {
    return {
      time,
      isLoading: false,
      result: null,
      page: 1,
      search: '',
      orderingOptions: [
        ['date_joined', 'date_joined'],
        ['last_activity', 'last_activity'],
        ['username', 'username']
      ]

    }
  },
  computed: {
    labels () {
      return {
        searchPlaceholder: this.$pgettext('Content/Search/Input.Placeholder', 'Search by username, e-mail address, name…')
      }
    },
    privacyLevels () {
      return {}
    },
    permissions () {
      return [
        {
          code: 'library',
          label: this.$pgettext('*/*/*/Noun', 'Library')
        },
        {
          code: 'moderation',
          label: this.$pgettext('*/Moderation/*', 'Moderation')
        },
        {
          code: 'settings',
          label: this.$pgettext('*/*/*/Noun', 'Settings')
        }
      ]
    },
    actionFilters () {
      const currentFilters = {
        q: this.search
      }
      if (this.filters) {
        return merge(currentFilters, this.filters)
      } else {
        return currentFilters
      }
    },
    actions () {
      return [
        // {
        //   name: 'delete',
        //   label: this.$pgettext('Content/Admin/Button.Label/Verb', 'Delete'),
        //   isDangerous: true
        // }
      ]
    }
  },
  watch: {
    search (newValue) {
      this.page = 1
      this.fetchData()
    },
    page () {
      this.fetchData()
    },
    ordering () {
      this.fetchData()
    },
    orderingDirection () {
      this.fetchData()
    }
  },
  created () {
    this.fetchData()
  },
  methods: {
    fetchData () {
      const params = merge({
        page: this.page,
        page_size: this.paginateBy,
        q: this.search,
        ordering: this.getOrderingAsString()
      }, this.filters)
      const self = this
      self.isLoading = true
      self.checked = []
      axios.get('/manage/users/users/', { params: params }).then((response) => {
        self.result = response.data
        self.isLoading = false
      }, error => {
        self.isLoading = false
        self.errors = error.backendErrors
      })
    },
    selectPage: function (page) {
      this.page = page
    }
  }
}
</script>
