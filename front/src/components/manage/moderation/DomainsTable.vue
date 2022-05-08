<template>
  <div>
    <div class="ui inline form">
      <div class="fields">
        <div class="ui field">
          <label for="domains-search"><translate translate-context="Content/Search/Input.Label/Noun">Search</translate></label>
          <input
            id="domains-search"
            v-model="search"
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
        :compact="true"
        :current="page"
        :paginate-by="paginateBy"
        :total="result.count"
        @page-changed="selectPage"
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

<script>
import axios from 'axios'
import { merge } from 'lodash-es'
import time from '~/utils/time'
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
    filters: { type: Object, required: false, default: function () { return {} } },
    allowListEnabled: { type: Boolean, default: false }
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
      allowed: null,
      orderingOptions: [
        ['name', 'name'],
        ['creation_date', 'first_seen'],
        ['actors_count', 'users'],
        ['outbox_activities_count', 'received_messages']
      ]

    }
  },
  computed: {
    labels () {
      return {
        searchPlaceholder: this.$pgettext('Content/Search/Input.Placeholder', 'Search by name…'),
        allowListTitle: this.$pgettext('Content/Moderation/Popup', 'This domain is present in your allow-list')
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
      return [
        {
          name: 'purge',
          label: this.$pgettext('*/*/*/Verb', 'Purge'),
          isDangerous: true
        },
        {
          name: 'allow_list_add',
          label: this.$pgettext('Content/Moderation/Action/Verb', 'Add to allow-list'),
          filterCheckable: (obj) => {
            return !obj.allowed
          }
        },
        {
          name: 'allow_list_remove',
          label: this.$pgettext('Content/Moderation/Action/Verb', 'Remove from allow-list'),
          filterCheckable: (obj) => {
            return obj.allowed
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
    allowed () {
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
      const baseFilters = {
        page: this.page,
        page_size: this.paginateBy,
        q: this.search,
        ordering: this.getOrderingAsString()
      }
      if (this.allowed !== null) {
        baseFilters.allowed = this.allowed
      }
      const params = merge(baseFilters, this.filters)
      const self = this
      self.isLoading = true
      self.checked = []
      axios.get('/manage/federation/domains/', { params: params }).then((response) => {
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
