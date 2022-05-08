<template>
  <div>
    <div class="ui inline form">
      <div class="fields">
        <div class="ui field">
          <label for="invitations-search"><translate translate-context="Content/Search/Input.Label/Noun">Search</translate></label>
          <input
            id="invitations-search"
            v-model="search"
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
import moment from 'moment'
import { merge } from 'lodash-es'
import Pagination from '~/components/vui/Pagination.vue'
import ActionTable from '~/components/common/ActionTable.vue'
import OrderingMixin from '~/components/mixins/Ordering.vue'
import useSharedLabels from '~/composables/locale/useSharedLabels'

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
      moment,
      isLoading: false,
      result: null,
      page: 1,
      search: '',
      isOpen: null,
      orderingOptions: [
        ['expiration_date', 'expiration_date'],
        ['creation_date', 'creation_date']
      ]

    }
  },
  computed: {
    labels () {
      return {
        searchPlaceholder: this.$pgettext('Content/Admin/Input.Placeholder/Verb', 'Search by username, e-mail address, code…')
      }
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
      const deleteLabel = this.$pgettext('*/*/*/Verb', 'Delete')
      return [
        {
          name: 'delete',
          label: deleteLabel,
          filterCheckable: (obj) => {
            return obj.users.length === 0 && moment().isBefore(obj.expiration_date)
          }
        }
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
      this.page = 1
      this.fetchData()
    },
    isOpen () {
      this.page = 1
      this.fetchData()
    },
    orderingDirection () {
      this.page = 1
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
        is_open: this.isOpen,
        ordering: this.getOrderingAsString()
      }, this.filters)
      const self = this
      self.isLoading = true
      self.checked = []
      axios.get('/manage/users/invitations/', { params: params }).then((response) => {
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
