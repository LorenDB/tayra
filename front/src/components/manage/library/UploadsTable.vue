<template>
  <div>
    <div class="ui inline form">
      <div class="fields">
        <div class="ui six wide field">
          <label for="uploads-search"><translate translate-context="Content/Search/Input.Label/Noun">Search</translate></label>
          <form @submit.prevent="search.query = $refs.search.value">
            <input
              id="uploads-search"
              ref="search"
              name="search"
              type="text"
              :value="search.query"
              :placeholder="labels.searchPlaceholder"
            >
          </form>
        </div>
        <div class="field">
          <label for="uploads-visibility"><translate translate-context="*/*/*">Visibility</translate></label>
          <select
            id="uploads-visibility"
            class="ui dropdown"
            :value="getTokenValue('privacy_level', '')"
            @change="addSearchToken('privacy_level', $event.target.value)"
          >
            <option value="">
              <translate translate-context="Content/*/Dropdown">
                All
              </translate>
            </option>
            <option value="me">
              {{ sharedLabels.fields.privacy_level.shortChoices.me }}
            </option>
            <option value="instance">
              {{ sharedLabels.fields.privacy_level.shortChoices.instance }}
            </option>
            <option value="everyone">
              {{ sharedLabels.fields.privacy_level.shortChoices.everyone }}
            </option>
          </select>
        </div>
        <div class="field">
          <label for="uploads-status"><translate translate-context="Content/*/*/Noun">Import status</translate></label>
          <select
            id="uploads-status"
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
          <label for="uploads-ordering"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering</translate></label>
          <select
            id="uploads-ordering"
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
          <label for="uploads-ordering-direction"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering direction</translate></label>
          <select
            id="uploads-ordering-direction"
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
      v-model:show="showUploadDetailModal"
      :upload="detailedUpload"
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
        action-url="manage/library/uploads/action/"
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
              Library
            </translate>
          </th>
          <th>
            <translate translate-context="*/*/*/Noun">
              Account
            </translate>
          </th>
          <th>
            <translate translate-context="Content/Moderation/*/Noun">
              Domain
            </translate>
          </th>
          <th>
            <translate translate-context="*/*/*">
              Visibility
            </translate>
          </th>
          <th>
            <translate translate-context="Content/*/*/Noun">
              Import status
            </translate>
          </th>
          <th>
            <translate translate-context="Content/*/*/Noun">
              Size
            </translate>
          </th>
          <th>
            <translate translate-context="Content/*/*/Noun">
              Creation date
            </translate>
          </th>
          <th>
            <translate translate-context="Content/*/*/Noun">
              Accessed date
            </translate>
          </th>
        </template>
        <template
          #row-cells="scope"
        >
          <td>
            <router-link :to="{name: 'manage.library.uploads.detail', params: {id: scope.obj.uuid }}">
              {{ truncate(displayName(scope.obj), 30, undefined, true) }}
            </router-link>
          </td>
          <td>
            <router-link :to="{name: 'manage.library.libraries.detail', params: {id: scope.obj.library.uuid }}">
              <i class="wrench icon" />
            </router-link>
            <a
              href=""
              class="discrete link"
              :title="scope.obj.library.name"
              @click.prevent="addSearchToken('library_id', scope.obj.library.id)"
            >
              {{ truncate(scope.obj.library.name, 20) }}
            </a>
          </td>
          <td>
            <router-link :to="{name: 'manage.moderation.accounts.detail', params: {id: scope.obj.library.actor.full_username }}" />
            <a
              href=""
              class="discrete link"
              :title="scope.obj.library.actor.full_username"
              @click.prevent="addSearchToken('account', scope.obj.library.actor.full_username)"
            >{{ scope.obj.library.actor.preferred_username }}</a>
          </td>
          <td>
            <template v-if="!scope.obj.is_local">
              <router-link :to="{name: 'manage.moderation.domains.detail', params: {id: scope.obj.domain }}">
                <i class="wrench icon" />
              </router-link>
              <a
                href=""
                class="discrete link"
                :title="scope.obj.domain"
                @click.prevent="addSearchToken('domain', scope.obj.domain)"
              >{{ scope.obj.domain }}</a>
            </template>
            <a
              v-else
              href=""
              class="ui tiny accent icon link label"
              @click.prevent="addSearchToken('domain', scope.obj.domain)"
            >
              <i class="home icon" />
              <translate translate-context="Content/Moderation/*/Short, Noun">Local</translate>
            </a>
          </td>
          <td>
            <a
              href=""
              class="discrete link"
              :title="sharedLabels.fields.privacy_level.shortChoices[scope.obj.library.privacy_level]"
              @click.prevent="addSearchToken('privacy_level', scope.obj.library.privacy_level)"
            >
              {{ sharedLabels.fields.privacy_level.shortChoices[scope.obj.library.privacy_level] }}
            </a>
          </td>
          <td>
            <a
              href=""
              class="discrete link"
              :title="sharedLabels.fields.import_status.choices[scope.obj.import_status].help"
              @click.prevent="addSearchToken('status', scope.obj.import_status)"
            >
              {{ sharedLabels.fields.import_status.choices[scope.obj.import_status].label }}
            </a>
            <button
              class="ui tiny basic icon button"
              :title="sharedLabels.fields.import_status.detailTitle"
              @click="detailedUpload = scope.obj; showUploadDetailModal = true"
            >
              <i class="question circle outline icon" />
            </button>
          </td>
          <td>
            <span v-if="scope.obj.size">{{ humanSize(scope.obj.size) }}</span>
            <translate
              v-else
              translate-context="*/*/*"
            >
              N/A
            </translate>
          </td>
          <td>
            <human-date :date="scope.obj.creation_date" />
          </td>
          <td>
            <human-date
              v-if="scope.obj.accessed_date"
              :date="scope.obj.accessed_date"
            />
            <translate
              v-else
              translate-context="*/*/*"
            >
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
import { normalizeQuery, parseTokens } from '~/utils/search'
import Pagination from '~/components/vui/Pagination.vue'
import ActionTable from '~/components/common/ActionTable.vue'
import OrderingMixin from '~/components/mixins/Ordering.vue'
import SmartSearchMixin from '~/components/mixins/SmartSearch.vue'
import ImportStatusModal from '~/components/library/ImportStatusModal.vue'
import { humanSize, truncate } from '~/utils/filters'
import useSharedLabels from '~/composables/locale/useSharedLabels'

export default {
  components: {
    Pagination,
    ActionTable,
    ImportStatusModal
  },
  mixins: [OrderingMixin, SmartSearchMixin],
  props: {
    filters: { type: Object, required: false, default: function () { return {} } }
  },
  setup () {
    const sharedLabels = useSharedLabels()
    return { sharedLabels, humanSize, truncate }
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
        ['modification_date', 'modification_date'],
        ['accessed_date', 'accessed_date'],
        ['size', 'size'],
        ['bitrate', 'bitrate'],
        ['duration', 'duration']
      ]
    }
  },
  computed: {
    labels () {
      return {
        searchPlaceholder: this.$pgettext('Content/Search/Input.Placeholder', 'Search by domain, actor, name, reference, source…')
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
      const confirmationMessage = this.$pgettext('Popup/*/Paragraph', 'The selected upload will be removed. This action is irreversible.')
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
      axios.get('/manage/library/uploads/', { params: params }).then((response) => {
        self.result = response.data
        self.isLoading = false
      }, error => {
        self.isLoading = false
        self.errors = error.backendErrors
      })
    },
    selectPage: function (page) {
      this.page = page
    },
    displayName (upload) {
      if (upload.filename) {
        return upload.filename
      }
      if (upload.source) {
        return upload.source
      }
      return upload.uuid
    }
  }
}
</script>
