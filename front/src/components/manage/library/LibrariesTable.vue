<template>
  <div>
    <div class="ui inline form">
      <div class="fields">
        <div class="ui six wide field">
          <label for="libraries-search"><translate translate-context="Content/Search/Input.Label/Noun">Search</translate></label>
          <form @submit.prevent="search.query = $refs.search.value">
            <input
              id="libraries-search"
              ref="search"
              name="search"
              type="text"
              :value="search.query"
              :placeholder="labels.searchPlaceholder"
            >
          </form>
        </div>
        <div class="field">
          <label for="libraries-visibility"><translate translate-context="*/*/*">Visibility</translate></label>
          <select
            id="libraries-visibility"
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
          <label for="libraries-ordering"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering</translate></label>
          <select
            id="libraries-ordering"
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
          <label for="libraries-ordering-direction"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering direction</translate></label>
          <select
            id="libraries-ordering-direction"
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
        action-url="manage/library/libraries/action/"
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
            <translate translate-context="*/*/*">
              Uploads
            </translate>
          </th>
          <th>
            <translate translate-context="Content/Federation/*/Noun">
              Followers
            </translate>
          </th>
          <th>
            <translate translate-context="Content/*/*/Noun">
              Creation date
            </translate>
          </th>
        </template>
        <template
          #row-cells="scope"
        >
          <td>
            <router-link :to="{name: 'manage.library.libraries.detail', params: {id: scope.obj.uuid }}">
              {{ scope.obj.name }}
            </router-link>
          </td>
          <td>
            <router-link :to="{name: 'manage.moderation.accounts.detail', params: {id: scope.obj.actor.full_username }}">
              <i class="wrench icon" />
            </router-link>
            <a
              href=""
              class="discrete link"
              :title="scope.obj.actor.full_username"
              @click.prevent="addSearchToken('account', scope.obj.actor.full_username)"
            >{{ scope.obj.actor.preferred_username }}</a>
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
              :title="sharedLabels.fields.privacy_level.shortChoices[scope.obj.privacy_level]"
              @click.prevent="addSearchToken('privacy_level', scope.obj.privacy_level)"
            >
              {{ sharedLabels.fields.privacy_level.shortChoices[scope.obj.privacy_level] }}
            </a>
          </td>
          <td>
            {{ scope.obj.uploads_count }}
          </td>
          <td>
            {{ scope.obj.followers_count }}
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
import { normalizeQuery, parseTokens } from '~/utils/search'
import Pagination from '~/components/Pagination.vue'
import ActionTable from '~/components/common/ActionTable.vue'
import OrderingMixin from '~/components/mixins/Ordering.vue'
import SmartSearchMixin from '~/components/mixins/SmartSearch.vue'
import useSharedLabels from '~/composables/locale/useSharedLabels'

export default {
  components: {
    Pagination,
    ActionTable
  },
  mixins: [OrderingMixin, SmartSearchMixin],
  props: {
    filters: { type: Object, required: false, default: () => { return {} } }
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
        ['followers_count', 'followers'],
        ['uploads_count', 'uploads']
      ]
    }
  },
  computed: {
    labels () {
      return {
        searchPlaceholder: this.$pgettext('Content/Search/Input.Placeholder', 'Search by domain, actor, name, description…')
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
      const confirmationMessage = this.$pgettext('Popup/*/Paragraph', 'The selected library will be removed, as well as associated uploads and follows. This action is irreversible.')
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
      axios.get('/manage/library/libraries/', { params: params }).then((response) => {
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
