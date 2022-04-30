<template>
  <div>
    <div class="ui inline form">
      <div class="fields">
        <div class="ui six wide field">
          <label for="files-search">
            <translate translate-context="Content/Search/Input.Label/Noun">Search</translate>
          </label>
          <form @submit.prevent="search.query = $refs.search.value">
            <input
              id="files-search"
              ref="search"
              name="search"
              type="text"
              :value="search.query"
              :placeholder="labels.searchPlaceholder"
            >
          </form>
        </div>
        <div class="field">
          <label for="import-status">
            <translate translate-context="Content/*/*/Noun">Import status</translate>
          </label>
          <select
            id="import-status"
            class="ui dropdown"
            :value="getTokenValue('status', '')"
            @change="addSearchToken('status', $event.target.value)"
          >
            <option value>
              <translate translate-context="Content/*/Dropdown">
                All
              </translate>
            </option>
            <option value="draft">
              <translate translate-context="Content/Library/*/Short">
                Draft
              </translate>
            </option>
            <option value="pending">
              <translate translate-context="Content/Library/*/Short">
                Pending
              </translate>
            </option>
            <option value="skipped">
              <translate translate-context="Content/Library/*">
                Skipped
              </translate>
            </option>
            <option value="errored">
              <translate translate-context="Content/Library/Dropdown">
                Failed
              </translate>
            </option>
            <option value="finished">
              <translate translate-context="Content/Library/*">
                Finished
              </translate>
            </option>
          </select>
        </div>
        <div class="field">
          <label for="ordering-select">
            <translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering</translate>
          </label>
          <select
            id="ordering-select"
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
          <label for="ordering-direction">
            <translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering direction</translate>
          </label>
          <select
            id="ordering-direction"
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
      <div
        v-else-if="!result && result.results.length === 0 && !needsRefresh"
        class="ui placeholder segment"
      >
        <div class="ui icon header">
          <i class="upload icon" />
          <translate
            translate-context="Content/Home/Placeholder"
          >
            No tracks have been added to this library yet
          </translate>
        </div>
      </div>
      <action-table
        v-else
        :id-field="'uuid'"
        :objects-data="result"
        :custom-objects="customObjects"
        :actions="actions"
        :refreshable="true"
        :needs-refresh="needsRefresh"
        :action-url="'uploads/action/'"
        :filters="actionFilters"
        @action-launched="fetchData"
        @refresh="fetchData"
      >
        <template slot="header-cells">
          <th>
            <translate translate-context="*/*/*/Noun">
              Title
            </translate>
          </th>
          <th>
            <translate translate-context="*/*/*/Noun">
              Artist
            </translate>
          </th>
          <th>
            <translate translate-context="*/*/*">
              Album
            </translate>
          </th>
          <th>
            <translate translate-context="*/*/*/Noun">
              Upload date
            </translate>
          </th>
          <th>
            <translate translate-context="Content/*/*/Noun">
              Import status
            </translate>
          </th>
          <th>
            <translate translate-context="Content/*/*">
              Duration
            </translate>
          </th>
          <th>
            <translate translate-context="Content/*/*/Noun">
              Size
            </translate>
          </th>
        </template>
        <template
          slot="row-cells"
          slot-scope="scope"
        >
          <template v-if="scope.obj.track">
            <td>
              <router-link :to="{name: 'library.tracks.detail', params: {id: scope.obj.track.id }}">
                {{ truncate(scope.obj.track.title, 25) }}
              </router-link>
            </td>
            <td>
              <a
                href=""
                class="discrete link"
                @click.prevent="addSearchToken('artist', scope.obj.track.artist.name)"
              >{{ truncate(scope.obj.track.artist.name, 20) }}</a>
            </td>
            <td>
              <a
                v-if="scope.obj.track.album"
                href=""
                class="discrete link"
                @click.prevent="addSearchToken('album', scope.obj.track.album.title)"
              >{{ truncate(scope.obj.track.album.title, 20) }}</a>
            </td>
          </template>
          <template v-else>
            <td :title="scope.obj.source">
              {{ truncate(scope.obj.source, 25) }}
            </td>
            <td />
            <td />
          </template>
          <td>
            <human-date :date="scope.obj.creation_date" />
          </td>
          <td>
            <a
              href=""
              class="discrete link"
              :title="sharedLabels.fields.import_status.choices[scope.obj.import_status].help"
              @click.prevent="addSearchToken('status', scope.obj.import_status)"
            >{{ sharedLabels.fields.import_status.choices[scope.obj.import_status].label }}</a>
            <button
              class="ui tiny basic icon button"
              :title="sharedLabels.fields.import_status.detailTitle"
              :aria-label="labels.showStatus"
              @click="detailedUpload = scope.obj; showUploadDetailModal = true"
            >
              <i class="question circle outline icon" />
            </button>
          </td>
          <td v-if="scope.obj.duration">
            {{ time.parse(scope.obj.duration) }}
          </td>
          <td v-else>
            <translate translate-context="*/*/*">
              N/A
            </translate>
          </td>
          <td v-if="scope.obj.size">
            {{ humanSize(scope.obj.size) }}
          </td>
          <td v-else>
            <translate translate-context="*/*/*">
              N/A
            </translate>
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
        @page-changed="page = $event; fetchData()"
      />

      <span v-if="result && result.results.length > 0">
        <translate
          translate-context="Content/*/Paragraph"
          :translate-params="{start: ((page-1) * paginateBy) + 1, end: ((page-1) * paginateBy) + result.results.length, total: result.count}"
        >Showing results %{ start }-%{ end } on %{ total }</translate>
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
import { humanSize, truncate } from '~/utils/filters'

export default {
  components: {
    Pagination,
    ActionTable,
    ImportStatusModal
  },
  mixins: [OrderingMixin, TranslationsMixin, SmartSearchMixin],
  props: {
    filters: { type: Object, required: false, default: function () { return {} } },
    needsRefresh: { type: Boolean, required: false, default: false },
    customObjects: {
      type: Array,
      required: false,
      default: () => {
        return []
      }
    }
  },
  setup () {
    return { humanSize, time, truncate }
  },
  data () {
    return {
      detailedUpload: {},
      showUploadDetailModal: false,
      isLoading: false,
      result: null,
      page: 1,
      search: {
        query: this.defaultQuery,
        tokens: parseTokens(normalizeQuery(this.defaultQuery))
      },
      orderingOptions: [
        ['creation_date', 'creation_date'],
        ['title', 'track_title'],
        ['size', 'size'],
        ['duration', 'duration'],
        ['bitrate', 'bitrate'],
        ['album_title', 'album_title'],
        ['artist_name', 'artist_name']
      ]
    }
  },
  computed: {
    labels () {
      return {
        searchPlaceholder: this.$pgettext(
          'Content/Library/Input.Placeholder',
          'Search by title, artist, album…'
        ),
        showStatus: this.$pgettext('Content/Library/Button.Label/Verb', 'Show information about the upload status for this track')
      }
    },
    actionFilters () {
      const currentFilters = {
        q: this.search.query,
        include_channels: 'true'
      }
      if (this.filters) {
        return merge(currentFilters, this.filters)
      } else {
        return currentFilters
      }
    },
    actions () {
      const deleteMsg = this.$pgettext('*/*/*/Verb', 'Delete')
      const relaunchMsg = this.$pgettext(
        'Content/Library/Dropdown/Verb',
        'Restart import'
      )
      return [
        {
          name: 'delete',
          label: deleteMsg,
          isDangerous: true,
          allowAll: true
        },
        {
          name: 'relaunch_import',
          label: relaunchMsg,
          isDangerous: true,
          allowAll: true,
          filterCheckable: f => {
            return f.import_status !== 'finished'
          }
        }
      ]
    }
  },
  watch: {
    orderingDirection: function () {
      this.page = 1
      this.fetchData()
    },
    page: function () {
      this.fetchData()
    },
    ordering: function () {
      this.page = 1
      this.fetchData()
    },
    search (newValue) {
      this.page = 1
      this.fetchData()
    }
  },
  created () {
    this.fetchData()
  },
  methods: {
    fetchData () {
      this.$emit('fetch-start')
      const params = merge(
        {
          page: this.page,
          page_size: this.paginateBy,
          ordering: this.getOrderingAsString(),
          q: this.search.query,
          include_channels: 'true'
        },
        this.filters || {}
      )
      const self = this
      self.isLoading = true
      self.checked = []
      axios.get('/uploads/', { params: params }).then(
        response => {
          self.result = response.data
          self.isLoading = false
        },
        error => {
          self.isLoading = false
          self.errors = error.backendErrors
        }
      )
    }
  }
}
</script>
