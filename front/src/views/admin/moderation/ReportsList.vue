<template>
  <main v-title="labels.reports">
    <section class="ui vertical stripe segment">
      <h2 class="ui header">
        <translate translate-context="*/Moderation/*/Noun">
          Reports
        </translate>
      </h2>
      <div class="ui hidden divider" />
      <div class="ui inline form">
        <div class="fields">
          <div class="ui field">
            <label for="reports-search"><translate translate-context="Content/Search/Input.Label/Noun">Search</translate></label>
            <form @submit.prevent="search.query = $refs.search.value">
              <input
                id="reports-search"
                ref="search"
                name="search"
                type="text"
                :value="search.query"
                :placeholder="labels.searchPlaceholder"
              >
            </form>
          </div>
          <div class="field">
            <label for="reports-status"><translate translate-context="*/*/*">Status</translate></label>
            <select
              id="reports-status"
              class="ui dropdown"
              :value="getTokenValue('resolved', '')"
              @change="addSearchToken('resolved', $event.target.value)"
            >
              <option value="">
                <translate translate-context="Content/*/Dropdown">
                  All
                </translate>
              </option>
              <option value="yes">
                <translate translate-context="Content/*/*/Short">
                  Resolved
                </translate>
              </option>
              <option value="no">
                <translate translate-context="Content/*/*/Short">
                  Unresolved
                </translate>
              </option>
            </select>
          </div>
          <report-category-dropdown
            class="field"
            :all="true"
            :label="true"
            :model-value="getTokenValue('category', '')"
            @update:model-value="addSearchToken('category', $event)"
          />
          <div class="field">
            <label for="reports-ordering"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering</translate></label>
            <select
              id="reports-ordering"
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
            <label for="reports-ordering-direction"><translate translate-context="Content/Search/Dropdown.Label/Noun">Order</translate></label>
            <select
              id="reports-ordering-direction"
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
      <div
        v-if="isLoading"
        class="ui active inverted dimmer"
      >
        <div class="ui loader" />
      </div>
      <div v-else-if="!result || result.count === 0">
        <empty-state
          :refresh="true"
          @refresh="fetchData()"
        />
      </div>
      <div v-else-if="mode === 'card'">
        <report-card
          v-for="obj in result.results"
          :key="obj.uuid"
          :init-obj="obj"
          @handled="fetchData"
        />
      </div>
      <div class="ui center aligned basic segment">
        <pagination
          v-if="result && result.count > paginateBy"
          :current="page"
          :paginate-by="paginateBy"
          :total="result.count"
          @page-changed="selectPage"
        />
      </div>
    </section>
  </main>
</template>

<script>

import axios from 'axios'
import { merge } from 'lodash-es'
import time from '~/utils/time'
import Pagination from '~/components/Pagination.vue'
import OrderingMixin from '~/components/mixins/Ordering.vue'
import ReportCard from '~/components/manage/moderation/ReportCard.vue'
import ReportCategoryDropdown from '~/components/moderation/ReportCategoryDropdown.vue'
import { normalizeQuery, parseTokens } from '~/search'
import SmartSearchMixin from '~/components/mixins/SmartSearch.vue'
import useSharedLabels from '../../../composables/useSharedLabels'

export default {
  components: {
    Pagination,
    ReportCard,
    ReportCategoryDropdown
  },
  mixins: [OrderingMixin, SmartSearchMixin],
  props: {
    mode: { type: String, default: 'card' }
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
      search: {
        query: this.defaultQuery,
        tokens: parseTokens(normalizeQuery(this.defaultQuery))
      },
      orderingOptions: [
        ['creation_date', 'creation_date'],
        ['applied_date', 'applied_date']
      ],
      targets: {
        track: {}
      }
    }
  },
  computed: {
    labels () {
      return {
        searchPlaceholder: this.$pgettext('Content/Search/Input.Placeholder', 'Search by account, summary, domain…'),
        reports: this.$pgettext('*/Moderation/*/Noun', 'Reports')
      }
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
        q: this.search.query,
        ordering: this.getOrderingAsString()
      }, this.filters)
      const self = this
      self.isLoading = true
      this.result = null
      axios.get('manage/moderation/reports/', { params: params }).then((response) => {
        self.result = response.data
        self.isLoading = false
        if (self.search.query === 'resolved:no') {
          console.log('Refreshing sidebar notifications')
          self.$store.commit('ui/incrementNotifications', { type: 'pendingReviewReports', value: response.data.count })
        }
      }, error => {
        self.isLoading = false
        self.errors = error.backendErrors
      })
    },
    selectPage: function (page) {
      this.page = page
    },
    handle (type, id, value) {
      if (type === 'delete') {
        this.exclude.push(id)
      }

      this.result.results.forEach((e) => {
        if (e.uuid === id) {
          e.is_approved = value
        }
      })
    },
    getCurrentState (target) {
      if (!target) {
        return {}
      }
      if (this.targets[target.type] && this.targets[target.type][String(target.id)]) {
        return this.targets[target.type][String(target.id)].currentState
      }
      return {}
    }
  }
}

</script>
