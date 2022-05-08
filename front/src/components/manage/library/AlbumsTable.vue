<template>
  <div>
    <div class="ui inline form">
      <div class="fields">
        <div class="ui six wide field">
          <label for="albums-search"><translate translate-context="Content/Search/Input.Label/Noun">Search</translate></label>
          <form @submit.prevent="search.query = $refs.search.value">
            <input
              id="albums-search"
              ref="search"
              name="search"
              type="text"
              :value="search.query"
              :placeholder="labels.searchPlaceholder"
            >
          </form>
        </div>
        <div class="field">
          <label for="albums-ordering"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering</translate></label>
          <select
            id="albums-ordering"
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
          <label for="albums-ordering-direction"><translate translate-context="Content/Search/Dropdown.Label/Noun">Ordering direction</translate></label>
          <select
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
        action-url="manage/library/albums/action/"
        :filters="actionFilters"
        @action-launched="fetchData"
      >
        <template #header-cells>
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
            <translate translate-context="Content/Moderation/*/Noun">
              Domain
            </translate>
          </th>
          <th>
            <translate translate-context="*/*/*">
              Tracks
            </translate>
          </th>
          <th>
            <translate translate-context="Content/*/*/Noun">
              Release date
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
            <router-link :to="{name: 'manage.library.albums.detail', params: {id: scope.obj.id }}">
              {{ scope.obj.title }}
            </router-link>
          </td>
          <td>
            <router-link :to="{name: 'manage.library.artists.detail', params: {id: scope.obj.artist.id }}">
              <i class="wrench icon" />
              <span class="visually-hidden">{{ labels.openModeration }}</span>
            </router-link>
            <a
              href=""
              class="discrete link"
              :title="scope.obj.artist.name"
              @click.prevent="addSearchToken('artist', scope.obj.artist.name)"
            >{{ scope.obj.artist.name }}</a>
          </td>
          <td>
            <template v-if="!scope.obj.is_local">
              <router-link :to="{name: 'manage.moderation.domains.detail', params: {id: scope.obj.domain }}">
                <i class="wrench icon" />
                <span class="visually-hidden">{{ labels.openModeration }}</span>
              </router-link>
              <a
                href=""
                class="discrete link"
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
            {{ scope.obj.tracks_count }}
          </td>
          <td>
            <human-date
              v-if="scope.obj.release_date"
              :date="scope.obj.release_date"
            />
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
        ['release_date', 'release_date'],
        ['name', 'name']
      ]
    }
  },
  computed: {
    labels () {
      return {
        searchPlaceholder: this.$pgettext('Content/Search/Input.Placeholder', 'Search by domain, title, artist, MusicBrainz ID…'),
        openModeration: this.$pgettext('Content/Moderation/Verb', 'Open in moderation interface')
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
      const confirmationMessage = this.$pgettext('Popup/*/Paragraph', 'The selected albums will be removed, as well as associated tracks, uploads, favorites and listening history. This action is irreversible.')
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
      axios.get('/manage/library/albums/', { params: params }).then((response) => {
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
