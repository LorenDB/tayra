<template>
  <main v-title="labels.reports">
    <section class="ui vertical stripe segment">
      <h2 class="ui header">
        <translate translate-context="*/Moderation/*/Noun">
          User Requests
        </translate>
      </h2>
      <div class="ui hidden divider" />
      <div class="ui inline form">
        <div class="fields">
          <div class="ui field">
            <label for="requests-search"><translate translate-context="Content/Search/Input.Label/Noun">Search</translate></label>
            <form @submit.prevent="search.query = $refs.search.value">
              <input
                id="requests-search"
                ref="search"
                name="search"
                type="text"
                :value="search.query"
                :placeholder="labels.searchPlaceholder"
              >
            </form>
          </div>
          <div class="field">
            <label for="requests-status"><translate translate-context="*/*/*">Status</translate></label>
            <select
              id="requests-status"
              class="ui dropdown"
              :value="getTokenValue('status', '')"
              @change="addSearchToken('status', $event.target.value)"
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
              <option value="approved">
                <translate translate-context="Content/*/*/Short">
                  Approved
                </translate>
              </option>
              <option value="refused">
                <translate translate-context="Content/*/*/Short">
                  Refused
                </translate>
              </option>
            </select>
          </div>
          <div class="field">
            <label for="requests-ordering"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering</translate></label>
            <select
              id="requests-ordering"
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
            <label for="requests-ordering-direction"><translate translate-context="Content/Search/Dropdown.Label/Noun">Order</translate></label>
            <select
              id="requests-ordering-direction"
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
      <template v-else>
        <user-request-card
          v-for="obj in result.results"
          :key="obj.uuid"
          :init-obj="obj"
          @handled="fetchData"
        />
        <div class="ui center aligned basic segment">
          <pagination
            v-if="result.count > paginateBy"
            :current="page"
            :paginate-by="paginateBy"
            :total="result.count"
            @page-changed="selectPage"
          />
        </div>
      </template>
    </section>
  </main>
</template>

<script>

import axios from 'axios'
import { merge } from 'lodash-es'
import time from '~/utils/time'
import Pagination from '~/components/Pagination.vue'
import OrderingMixin from '~/components/mixins/Ordering.vue'
import TranslationsMixin from '~/components/mixins/Translations.vue'
import UserRequestCard from '~/components/manage/moderation/UserRequestCard.vue'
import { normalizeQuery, parseTokens } from '~/search'
import SmartSearchMixin from '~/components/mixins/SmartSearch.vue'

export default {
  components: {
    Pagination,
    UserRequestCard
  },
  mixins: [OrderingMixin, TranslationsMixin, SmartSearchMixin],
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
        ['handled_date', 'handled_date']
      ],
      targets: {
        track: {}
      }
    }
  },
  computed: {
    labels () {
      return {
        searchPlaceholder: this.$pgettext('Content/Search/Input.Placeholder', 'Search by username…'),
        reports: this.$pgettext('*/Moderation/*/Noun', 'User Requests')
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
      axios.get('manage/moderation/requests/', { params: params }).then((response) => {
        self.result = response.data
        self.isLoading = false
        if (self.search.query === 'status:pending') {
          self.$store.commit('ui/incrementNotifications', { type: 'pendingReviewRequests', value: response.data.count })
        }
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
