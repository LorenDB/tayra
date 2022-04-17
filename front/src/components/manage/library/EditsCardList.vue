<template>
  <div class="ui text container">
    <slot />
    <div class="ui inline form">
      <div class="fields">
        <div class="ui field">
          <label for="search-edits"><translate translate-context="Content/Search/Input.Label/Noun">Search</translate></label>
          <form @submit.prevent="search.query = $refs.search.value">
            <input
              id="search-edits"
              ref="search"
              name="search"
              type="text"
              :value="search.query"
              :placeholder="labels.searchPlaceholder"
            >
          </form>
        </div>
        <div class="field">
          <label for="edit-status"><translate translate-context="*/*/*">Status</translate></label>
          <select
            id="edit-status"
            class="ui dropdown"
            :value="getTokenValue('is_approved', '')"
            @change="addSearchToken('is_approved', $event.target.value)"
          >
            <option value="">
              <translate translate-context="Content/*/Dropdown">
                All
              </translate>
            </option>
            <option value="null">
              <translate translate-context="Content/Admin/*/Noun">
                Pending review
              </translate>
            </option>
            <option value="yes">
              <translate translate-context="Content/*/*/Short">
                Approved
              </translate>
            </option>
            <option value="no">
              <translate translate-context="Content/Library/*/Short">
                Rejected
              </translate>
            </option>
          </select>
        </div>
        <div class="field">
          <label for="edit-ordering"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering</translate></label>
          <select
            id="edit-ordering"
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
          <label for="edit-ordering-direction"><translate translate-context="Content/Search/Dropdown.Label/Noun">Order</translate></label>
          <select
            id="edit-ordering-direction"
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
      <div v-else-if="result && result.count > 0">
        <edit-card
          v-for="obj in result.results"
          :key="obj.uuid"
          :obj="obj"
          :current-state="getCurrentState(obj.target)"
          @deleted="handle('delete', obj.uuid, null)"
          @approved="handle('approved', obj.uuid, $event)"
        />
      </div>
      <empty-state
        v-else
        :refresh="true"
        @refresh="fetchData()"
      />
    </div>
    <div class="ui hidden divider" />
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
import { uniq, merge } from 'lodash-es'
import time from '@/utils/time'
import Pagination from '@/components/Pagination.vue'
import OrderingMixin from '@/components/mixins/Ordering.vue'
import TranslationsMixin from '@/components/mixins/Translations.vue'
import EditCard from '@/components/library/EditCard.vue'
import { normalizeQuery, parseTokens } from '@/search'
import SmartSearchMixin from '@/components/mixins/SmartSearch.vue'

import edits from '@/edits'

export default {
  components: {
    Pagination,
    EditCard
  },
  mixins: [OrderingMixin, TranslationsMixin, SmartSearchMixin],
  props: {
    filters: { type: Object, required: false, default: () => { return {} } }
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
        searchPlaceholder: this.$pgettext('Content/Search/Input.Placeholder', 'Search by account, summary, domain…')
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
      axios.get('mutations/', { params: params }).then((response) => {
        self.result = response.data
        self.isLoading = false
        self.fetchTargets()
      }, error => {
        self.isLoading = false
        self.errors = error.backendErrors
      })
    },
    fetchTargets () {
      // we request target data via the API so we can display previous state
      // additionnal data next to the edit card
      const self = this
      const typesAndIds = {
        track: {
          url: 'tracks/',
          ids: []
        }
      }
      this.result.results.forEach((m) => {
        if (!m.target || !typesAndIds[m.target.type]) {
          return
        }
        typesAndIds[m.target.type].ids.push(m.target.id)
      })
      Object.keys(typesAndIds).forEach((k) => {
        const config = typesAndIds[k]
        if (config.ids.length === 0) {
          return
        }
        axios.get(config.url, { params: { id: uniq(config.ids), hidden: 'null' } }).then((response) => {
          response.data.results.forEach((e) => {
            self.$set(self.targets[k], e.id, {
              payload: e,
              currentState: edits.getCurrentStateForObj(e, edits.getConfigs.bind(self)()[k])
            })
          })
        }, error => {
          self.errors = error.backendErrors
        })
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
