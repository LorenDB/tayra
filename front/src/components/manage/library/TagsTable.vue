<template>
  <div>
    <div class="ui inline form">
      <div class="fields">
        <div class="ui six wide field">
          <label for="tags-search"><translate translate-context="Content/Search/Input.Label/Noun">Search</translate></label>
          <form @submit.prevent="search.query = $refs.search.value">
            <input
              id="tags-search"
              ref="search"
              name="search"
              type="text"
              :value="search.query"
              :placeholder="labels.searchPlaceholder"
            >
          </form>
        </div>
        <div class="field">
          <label for="tags-ordering"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering</translate></label>
          <select
            id="tags-ordering"
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
          <label for="tags-ordering-direction"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering direction</translate></label>
          <select
            id="tags-ordering-direction"
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
    <import-status-modal
      :upload="detailedUpload"
      :show.sync="showUploadDetailModal"
    />
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
        action-url="manage/tags/action/"
        id-field="name"
        :filters="actionFilters"
        @action-launched="fetchData"
      >
        <template slot="header-cells">
          <th>
            <translate translate-context="*/*/*/Noun">
              Name
            </translate>
          </th>
          <th>
            <translate translate-context="*/*/*/Noun">
              Artists
            </translate>
          </th>
          <th>
            <translate translate-context="*/*/*">
              Albums
            </translate>
          </th>
          <th>
            <translate translate-context="*/*/*">
              Tracks
            </translate>
          </th>
          <th>
            <translate translate-context="Content/*/*/Noun">
              Creation date
            </translate>
          </th>
        </template>
        <template
          slot="row-cells"
          slot-scope="scope"
        >
          <td>
            <router-link :to="{name: 'manage.library.tags.detail', params: {id: scope.obj.name }}">
              {{ scope.obj.name|truncate(30, "…", true) }}
            </router-link>
          </td>
          <td>
            {{ scope.obj.artists_count }}
          </td>
          <td>
            {{ scope.obj.albums_count }}
          </td>
          <td>
            {{ scope.obj.tracks_count }}
          </td>
          <td>
            <human-date :date="scope.obj.creation_date" />
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
import { normalizeQuery, parseTokens } from '~/search'
import Pagination from '~/components/Pagination.vue'
import ActionTable from '~/components/common/ActionTable.vue'
import OrderingMixin from '~/components/mixins/Ordering.vue'
import TranslationsMixin from '~/components/mixins/Translations.vue'
import SmartSearchMixin from '~/components/mixins/SmartSearch.vue'
import ImportStatusModal from '~/components/library/ImportStatusModal.vue'

export default {
  components: {
    Pagination,
    ActionTable,
    ImportStatusModal
  },
  mixins: [OrderingMixin, TranslationsMixin, SmartSearchMixin],
  props: {
    filters: { type: Object, required: false, default: () => { return {} } }
  },
  data () {
    return {
      detailedUpload: {},
      showUploadDetailModal: false,
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
        ['name', 'name'],
        ['length', 'length'],
        ['items_count', 'items_count']
      ]
    }
  },
  computed: {
    labels () {
      return {
        searchPlaceholder: this.$pgettext('Content/Search/Input.Placeholder', 'Search by name')
      }
    },
    actionFilters () {
      const currentFilters = {
        q: this.search.query
      }
      if (this.filters) {
        return merge(currentFilters, this.filters)
      } else {
        return currentFilters
      }
    },
    actions () {
      const deleteLabel = this.$pgettext('*/*/*/Verb', 'Delete')
      const confirmationMessage = this.$pgettext('Popup/*/Paragraph', 'The selected tag will be removed and unlinked with existing content, if any. This action is irreversible.')
      return [
        {
          name: 'delete',
          label: deleteLabel,
          confirmationMessage: confirmationMessage,
          isDangerous: true,
          allowAll: false,
          confirmColor: 'danger'
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
      self.checked = []
      axios.get('/manage/tags/', { params: params }).then((response) => {
        self.isLoading = false
        self.result = response.data
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
